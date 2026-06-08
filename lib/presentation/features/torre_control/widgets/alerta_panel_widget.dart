import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/alerta_seguridad.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

final alertasStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return sl<FirestoreDatasource>().watchAlertasActivas();
});

class AlertaPanelWidget extends ConsumerWidget {
  const AlertaPanelWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertasSP = ref.watch(alertasStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelHeader(
          icon: Icons.warning_amber_rounded,
          title: 'Alertas de Seguridad',
          color: GloboColors.error,
          count: alertasSP.valueOrNull?.length ?? 0,
        ),
        Expanded(
          child: alertasSP.when(
            loading: () => const Center(
                child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(e.toString())),
            data: (alertas) => alertas.isEmpty
                ? const _EmptyAlertasView()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: alertas.length,
                    itemBuilder: (ctx, i) =>
                        _AlertaItem(data: alertas[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AlertaItem extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AlertaItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final tipo = data['tipo'] as String? ?? '';
    final esSOS = tipo == TipoAlerta.sos.name;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: esSOS
                ? GloboColors.sosPrimary
                : GloboColors.warning,
            width: 4,
          ),
        ),
        color: esSOS
            ? GloboColors.errorLight
            : GloboColors.warningLight,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          esSOS ? Icons.sos : Icons.warning_outlined,
          color: esSOS ? GloboColors.sosPrimary : GloboColors.warning,
          size: 20,
        ),
        title: Text(
          esSOS ? 'PROTOCOLO SOS ACTIVO' : _tipoLabel(tipo),
          style: GloboTypography.labelLarge.copyWith(
            color: esSOS ? GloboColors.sosPrimary : GloboColors.warning,
          ),
        ),
        subtitle: Text(
          data['operador_id'] as String? ?? '',
          style: GloboTypography.caption,
        ),
        trailing: esSOS
            ? _SosPulse()
            : const Icon(Icons.chevron_right, size: 16),
      ),
    );
  }

  String _tipoLabel(String tipo) => switch (tipo) {
        'geocerca' => 'Violación de Geocerca',
        'varianzaCombustible' => 'Varianza Combustible',
        'detencionProlongada' => 'Detención Prolongada',
        _ => tipo,
      };
}

class _SosPulse extends StatefulWidget {
  @override
  State<_SosPulse> createState() => _SosPulseState();
}

class _SosPulseState extends State<_SosPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GloboColors.sosPrimary,
          borderRadius: GloboRadius.buttonRadius,
        ),
        child: const Text(
          'ACTIVO',
          style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _EmptyAlertasView extends StatelessWidget {
  const _EmptyAlertasView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              color: GloboColors.success, size: 32),
          const SizedBox(height: GloboSpacing.sm),
          Text('Sin alertas activas',
              style: GloboTypography.bodyMedium
                  .copyWith(color: GloboColors.success)),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final int count;

  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: GloboColors.divider)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: GloboSpacing.sm),
          Text(title, style: GloboTypography.titleMedium),
          const Spacer(),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius:
                    const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: color.withAlpha(60)),
              ),
              child: Text(
                '$count',
                style: GloboTypography.labelSmall
                    .copyWith(color: color),
              ),
            ),
        ],
      ),
    );
  }
}
