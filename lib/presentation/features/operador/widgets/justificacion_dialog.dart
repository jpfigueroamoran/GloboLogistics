import 'package:flutter/material.dart';
import '../../../../core/constants/theme_constants.dart';

class JustificacionDialog extends StatefulWidget {
  const JustificacionDialog({super.key});

  @override
  State<JustificacionDialog> createState() => _JustificacionDialogState();
}

class _JustificacionDialogState extends State<JustificacionDialog> {
  String? _motivoSeleccionado;
  final _otrosController = TextEditingController();

  final List<String> _motivos = [
    'Tráfico pesado o embotellamiento',
    'Desvío forzoso por accidente o retén',
    'Clima extremo (lluvia/niebla)',
    'Problemas mecánicos menores',
    'Otro (especificar)'
  ];

  @override
  void dispose() {
    _otrosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: GloboColors.warning),
          const SizedBox(width: GloboSpacing.sm),
          Expanded(
            child: Text(
              'Consumo Atípico Detectado',
              style: GloboTypography.titleMedium,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hemos detectado una varianza en el consumo de combustible mayor a lo planeado para esta ruta.\n\n¿Hubo algún contratiempo que explique esta diferencia? Tu reporte nos ayuda a mejorar nuestras rutas.',
              style: GloboTypography.bodyMedium,
            ),
            const SizedBox(height: GloboSpacing.md),
            ..._motivos.map((m) => RadioListTile<String>(
                  title: Text(m, style: GloboTypography.bodyMedium),
                  value: m,
                  groupValue: _motivoSeleccionado,
                  onChanged: (val) {
                    setState(() => _motivoSeleccionado = val);
                  },
                  contentPadding: EdgeInsets.zero,
                )),
            if (_motivoSeleccionado == 'Otro (especificar)') ...[
              const SizedBox(height: GloboSpacing.sm),
              TextField(
                controller: _otrosController,
                decoration: InputDecoration(
                  hintText: 'Describe el motivo...',
                  border: OutlineInputBorder(
                    borderRadius: GloboRadius.buttonRadius,
                  ),
                ),
                maxLines: 2,
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Si no quiere justificar, se envía vacío
            Navigator.of(context).pop('');
          },
          child: const Text('Omitir', style: TextStyle(color: GloboColors.steelGray)),
        ),
        ElevatedButton(
          onPressed: _motivoSeleccionado != null
              ? () {
                  final motivo = _motivoSeleccionado == 'Otro (especificar)'
                      ? _otrosController.text
                      : _motivoSeleccionado!;
                  Navigator.of(context).pop(motivo);
                }
              : null,
          child: const Text('Enviar Reporte'),
        ),
      ],
    );
  }
}
