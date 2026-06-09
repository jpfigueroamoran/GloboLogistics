import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/theme_constants.dart';
import '../../../../demo/demo_providers.dart';

class DemoLoginPage extends ConsumerWidget {
  const DemoLoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: GloboSpacing.xl),
            width: 400,
            padding: const EdgeInsets.all(GloboSpacing.xl),
            decoration: BoxDecoration(
              color: GloboColors.surface,
              borderRadius: GloboRadius.cardRadius,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hub, size: 64, color: GloboColors.primary),
                const SizedBox(height: GloboSpacing.md),
                Text('Globo Logistics', style: GloboTypography.headlineLarge),
                Text('DEMO MODE', style: GloboTypography.labelSmall.copyWith(color: GloboColors.accentGlow, letterSpacing: 2)),
                const SizedBox(height: GloboSpacing.xl),
                
                _LoginButton(
                  icon: Icons.local_shipping,
                  label: 'Ingresar como Operador',
                  color: GloboColors.estadoTransito,
                  onTap: () => ref.read(demoUserProvider.notifier).state = operadorDemo,
                ),
                const SizedBox(height: GloboSpacing.md),
                _LoginButton(
                  icon: Icons.dashboard,
                  label: 'Ingresar como Supervisor',
                  color: GloboColors.primary,
                  onTap: () => ref.read(demoUserProvider.notifier).state = supervisorDemo,
                ),
                const SizedBox(height: GloboSpacing.md),
                _LoginButton(
                  icon: Icons.admin_panel_settings,
                  label: 'Ingresar como Administrador',
                  color: GloboColors.accentBright,
                  onTap: () => ref.read(demoUserProvider.notifier).state = adminDemo,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LoginButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: GloboRadius.buttonRadius,
      child: Container(
        padding: const EdgeInsets.all(GloboSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(80)),
          borderRadius: GloboRadius.buttonRadius,
          color: color.withAlpha(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: GloboSpacing.md),
            Text(label, style: GloboTypography.titleMedium.copyWith(color: color)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: color.withAlpha(100)),
          ],
        ),
      ),
    );
  }
}
