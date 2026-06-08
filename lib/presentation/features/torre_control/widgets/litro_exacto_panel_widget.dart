import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../core/services/fuel_gauge_service.dart';
import '../../../../domain/entities/auditoria_resultado.dart';
import '../../../../domain/usecases/auditoria/auditoria_diesel_usecase.dart';
import '../../../../injection_container.dart';

// Estado local del panel de auditoría
class _PanelState {
  final bool calculando;
  final AuditoriaResultado? resultado;
  final String? error;

  const _PanelState({
    this.calculando = false,
    this.resultado,
    this.error,
  });

  _PanelState copyWith({
    bool? calculando,
    AuditoriaResultado? resultado,
    String? error,
  }) =>
      _PanelState(
        calculando: calculando ?? this.calculando,
        resultado: resultado ?? this.resultado,
        error: error ?? this.error,
      );
}

final _panelStateProvider =
    StateProvider<_PanelState>((_) => const _PanelState());

// Formulario de parámetros del viaje
class _FormData {
  double odometroInicio = 0;
  double odometroFin = 0;
  double capacidadTanque = 300;
  double rendimientoBase = 3.5;
  double litrosTickets = 0;
  double credibilidadOcr = 75;
  FuelGaugeBand? medidorAntes;
  FuelGaugeBand? medidorDespues;
  FuelGaugeStatus estadoMedidor = FuelGaugeStatus.reliable;
  String viajeId = '';
}

class LitroExactoPanelWidget extends ConsumerStatefulWidget {
  const LitroExactoPanelWidget({super.key});

  @override
  ConsumerState<LitroExactoPanelWidget> createState() =>
      _LitroExactoPanelWidgetState();
}

class _LitroExactoPanelWidgetState
    extends ConsumerState<LitroExactoPanelWidget> {
  final _form = _FormData();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_panelStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _PanelHeader(),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.resultado != null)
                  _ResultadoCard(resultado: state.resultado!)
                else ...[
                  _FormSection(form: _form),
                  const SizedBox(height: GloboSpacing.lg),
                ],

                if (state.error != null)
                  _ErrorCard(message: state.error!),

                if (state.resultado == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: state.calculando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.calculate_outlined),
                      label: Text(state.calculando
                          ? 'Calculando...'
                          : 'Ejecutar Auditoría'),
                      onPressed: state.calculando ? null : _ejecutarAuditoria,
                    ),
                  ),

                if (state.resultado != null) ...[
                  const SizedBox(height: GloboSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Nueva Auditoría'),
                      onPressed: () => ref
                          .read(_panelStateProvider.notifier)
                          .state = const _PanelState(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _ejecutarAuditoria() async {
    ref.read(_panelStateProvider.notifier).state =
        const _PanelState(calculando: true);

    final usecase = sl<AuditoriaDieselUsecase>();
    final result = await usecase(AuditoriaDieselParams(
      viajeId: _form.viajeId,
      odometroInicio: _form.odometroInicio,
      odometroFin: _form.odometroFin,
      capacidadTanque: _form.capacidadTanque,
      rendimientoBaseKmL: _form.rendimientoBase,
      litrosTickets: _form.litrosTickets,
      credibilidadOcrPromedio: _form.credibilidadOcr,
      medidorAntes: _form.medidorAntes,
      medidorDespues: _form.medidorDespues,
      estadoMedidor: _form.estadoMedidor,
    ));

    result.fold(
      (failure) => ref
          .read(_panelStateProvider.notifier)
          .state = _PanelState(error: failure.message),
      (resultado) => ref
          .read(_panelStateProvider.notifier)
          .state = _PanelState(resultado: resultado),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GloboSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GloboColors.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station_outlined,
              color: GloboColors.primary, size: 18),
          const SizedBox(width: GloboSpacing.sm),
          Text('Litro Exacto',
              style: GloboTypography.titleMedium),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: GloboColors.infoLight,
              borderRadius:
                  const BorderRadius.all(Radius.circular(4)),
            ),
            child: Text(
              'Motor v2.0',
              style: GloboTypography.labelSmall
                  .copyWith(color: GloboColors.info, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatefulWidget {
  final _FormData form;

  const _FormSection({required this.form});

  @override
  State<_FormSection> createState() => _FormSectionState();
}

class _FormSectionState extends State<_FormSection> {
  @override
  Widget build(BuildContext context) {
    final f = widget.form;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Parámetros del Viaje',
            style: GloboTypography.titleMedium),
        const SizedBox(height: GloboSpacing.md),

        _NumField(
          label: 'ID de Viaje',
          hint: 'ABC123',
          onChanged: (v) => f.viajeId = v,
          isText: true,
        ),
        _NumField(
          label: 'Odómetro Inicio (km)',
          hint: '0',
          onChanged: (v) =>
              f.odometroInicio = double.tryParse(v) ?? 0,
        ),
        _NumField(
          label: 'Odómetro Fin (km)',
          hint: '0',
          onChanged: (v) =>
              f.odometroFin = double.tryParse(v) ?? 0,
        ),

        const Divider(height: GloboSpacing.xl),
        Text('Datos de la Unidad',
            style: GloboTypography.titleMedium),
        const SizedBox(height: GloboSpacing.md),

        _NumField(
          label: 'Capacidad del Tanque (L)',
          hint: '300',
          initialValue: '300',
          onChanged: (v) =>
              f.capacidadTanque = double.tryParse(v) ?? 300,
        ),
        _NumField(
          label: 'Rendimiento base (km/L)',
          hint: '3.5',
          initialValue: '3.5',
          onChanged: (v) =>
              f.rendimientoBase = double.tryParse(v) ?? 3.5,
        ),

        const Divider(height: GloboSpacing.xl),
        Text('Auditoría OCR',
            style: GloboTypography.titleMedium),
        const SizedBox(height: GloboSpacing.md),

        _NumField(
          label: 'Total Litros Tickets OCR (L)',
          hint: '0',
          onChanged: (v) =>
              f.litrosTickets = double.tryParse(v) ?? 0,
        ),
        _NumField(
          label: 'Credibilidad OCR promedio (0–100)',
          hint: '75',
          initialValue: '75',
          onChanged: (v) =>
              f.credibilidadOcr = double.tryParse(v) ?? 75,
        ),

        const Divider(height: GloboSpacing.xl),
        Text('Medidor de Tablero',
            style: GloboTypography.titleMedium),
        const SizedBox(height: GloboSpacing.sm),

        // Estado del medidor
        Row(
          children: [
            Text('Medidor:', style: GloboTypography.bodyMedium),
            const SizedBox(width: GloboSpacing.md),
            _MedidorStatusChip(
              label: 'Confiable',
              isSelected: f.estadoMedidor == FuelGaugeStatus.reliable,
              onTap: () =>
                  setState(() => f.estadoMedidor = FuelGaugeStatus.reliable),
            ),
            const SizedBox(width: GloboSpacing.sm),
            _MedidorStatusChip(
              label: 'No confiable',
              isSelected: f.estadoMedidor == FuelGaugeStatus.unreliable,
              isNegative: true,
              onTap: () => setState(
                  () => f.estadoMedidor = FuelGaugeStatus.unreliable),
            ),
          ],
        ),

        if (f.estadoMedidor == FuelGaugeStatus.reliable) ...[
          const SizedBox(height: GloboSpacing.sm),
          _BandDropdown(
            label: 'Nivel antes de carga',
            value: f.medidorAntes,
            onChanged: (b) =>
                setState(() => f.medidorAntes = b),
          ),
          const SizedBox(height: GloboSpacing.sm),
          _BandDropdown(
            label: 'Nivel después de carga',
            value: f.medidorDespues,
            onChanged: (b) =>
                setState(() => f.medidorDespues = b),
          ),
        ],
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final String hint;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final bool isText;

  const _NumField({
    required this.label,
    required this.hint,
    required this.onChanged,
    this.initialValue,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GloboSpacing.sm),
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: isText
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        style: GloboTypography.monoData.copyWith(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
  }
}

class _BandDropdown extends StatelessWidget {
  final String label;
  final FuelGaugeBand? value;
  final ValueChanged<FuelGaugeBand?> onChanged;

  const _BandDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: DropdownButton<FuelGaugeBand>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        isDense: true,
        items: FuelGaugeBand.standardBands
            .map((b) => DropdownMenuItem(
                  value: b,
                  child: Text(b.label,
                      style: GloboTypography.bodyMedium),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _MedidorStatusChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isNegative;
  final VoidCallback onTap;

  const _MedidorStatusChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isNegative ? GloboColors.warning : GloboColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withAlpha(15),
          borderRadius: GloboRadius.buttonRadius,
          border: Border.all(
              color: isSelected ? color : color.withAlpha(60)),
        ),
        child: Text(
          label,
          style: GloboTypography.labelSmall.copyWith(
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ── Resultado de la auditoría ─────────────────────────────────────────────────

class _ResultadoCard extends StatelessWidget {
  final AuditoriaResultado resultado;

  const _ResultadoCard({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final color = resultado.tieneBanderaRoja
        ? GloboColors.error
        : GloboColors.success;
    final bgColor = resultado.tieneBanderaRoja
        ? GloboColors.errorLight
        : GloboColors.successLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera de resultado
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(GloboSpacing.md),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: GloboRadius.cardRadius,
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    resultado.tieneBanderaRoja
                        ? Icons.flag
                        : Icons.check_circle_outline,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: GloboSpacing.sm),
                  Text(
                    resultado.nivel.label.toUpperCase(),
                    style: GloboTypography.labelLarge
                        .copyWith(color: color, letterSpacing: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: GloboSpacing.sm),
              Text(
                'Varianza: ${resultado.varianzaPct.toStringAsFixed(2)}%',
                style: GloboTypography.displayMedium
                    .copyWith(color: color),
              ),
            ],
          ),
        ),

        const SizedBox(height: GloboSpacing.md),

        // Tabla de conciliación
        Card(
          child: Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conciliación',
                    style: GloboTypography.titleMedium),
                const SizedBox(height: GloboSpacing.sm),
                _ConciliacionRow(
                  label: 'Tickets OCR',
                  valor: '${resultado.litrosTickets.toStringAsFixed(2)} L',
                  color: GloboColors.primaryAccent,
                ),
                _ConciliacionRow(
                  label: 'Telemetría',
                  valor: '${resultado.litrosTelemetria.toStringAsFixed(2)} L',
                  color: GloboColors.steelGray,
                ),
                const Divider(height: GloboSpacing.md),
                _ConciliacionRow(
                  label: 'Delta',
                  valor: '${resultado.deltaLitros.toStringAsFixed(2)} L',
                  color: resultado.tieneBanderaRoja
                      ? GloboColors.error
                      : GloboColors.success,
                  bold: true,
                ),
                _ConciliacionRow(
                  label: 'Tolerancia dinámica',
                  valor:
                      '${resultado.toleranciaDinamica.toStringAsFixed(2)} L',
                  color: GloboColors.textTertiary,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: GloboSpacing.sm),

        // Scores
        Card(
          child: Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calidad de Evidencia',
                    style: GloboTypography.titleMedium),
                const SizedBox(height: GloboSpacing.sm),
                _ScoreBar(
                  label: 'Coherencia volumétrica',
                  score: resultado.coherenciaVolumetrica,
                ),
                _ScoreBar(
                  label: 'Credibilidad OCR',
                  score: resultado.credibilidadOcr,
                ),
                _ScoreBar(
                  label: 'Score compuesto',
                  score: resultado.scoreCompuesto,
                  highlighted: true,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: GloboSpacing.sm),

        // Nota técnica
        Container(
          padding: const EdgeInsets.all(GloboSpacing.sm),
          decoration: BoxDecoration(
            color: GloboColors.backgroundSecondary,
            borderRadius: GloboRadius.buttonRadius,
          ),
          child: Text(
            resultado.notaVolumetrica,
            style: GloboTypography.caption,
          ),
        ),
      ],
    );
  }
}

class _ConciliacionRow extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  final bool bold;

  const _ConciliacionRow({
    required this.label,
    required this.valor,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GloboTypography.bodyMedium
                    .copyWith(fontWeight: bold ? FontWeight.w600 : null)),
          ),
          Text(
            valor,
            style: GloboTypography.monoData.copyWith(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: bold ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double score;
  final bool highlighted;

  const _ScoreBar({
    required this.label,
    required this.score,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = (score / 100).clamp(0.0, 1.0);
    final color = score >= 75
        ? GloboColors.success
        : score >= 50
            ? GloboColors.warning
            : GloboColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: GloboSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: highlighted
                    ? GloboTypography.labelLarge
                    : GloboTypography.bodyMedium,
              ),
              const Spacer(),
              Text(
                '${score.toStringAsFixed(0)}',
                style: GloboTypography.monoData.copyWith(
                  color: color,
                  fontWeight: highlighted
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontSize: highlighted ? 16 : 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            child: LinearProgressIndicator(
              value: normalized,
              backgroundColor: GloboColors.backgroundTertiary,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: highlighted ? 8 : 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GloboSpacing.sm),
      margin: const EdgeInsets.only(bottom: GloboSpacing.md),
      decoration: BoxDecoration(
        color: GloboColors.errorLight,
        borderRadius: GloboRadius.buttonRadius,
        border: const Border(
            left: BorderSide(color: GloboColors.error, width: 3)),
      ),
      child: Text(message,
          style: GloboTypography.bodyMedium
              .copyWith(color: GloboColors.error)),
    );
  }
}
