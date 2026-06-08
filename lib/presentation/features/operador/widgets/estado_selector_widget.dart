import 'package:flutter/material.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/actividad_operativa.dart';

class EstadoSelectorWidget extends StatelessWidget {
  final EstadoOperador estadoActual;
  final ValueChanged<EstadoOperador> onEstadoChanged;

  const EstadoSelectorWidget({
    super.key,
    required this.estadoActual,
    required this.onEstadoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado de Operación',
                style: GloboTypography.titleMedium),
            const SizedBox(height: GloboSpacing.md),
            Row(
              children: EstadoOperador.values.map((estado) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4),
                    child: _EstadoChip(
                      estado: estado,
                      isSelected: estadoActual == estado,
                      onTap: () => onEstadoChanged(estado),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final EstadoOperador estado;
  final bool isSelected;
  final VoidCallback onTap;

  const _EstadoChip({
    required this.estado,
    required this.isSelected,
    required this.onTap,
  });

  Color get _color => switch (estado) {
        EstadoOperador.offline => GloboColors.estadoOffline,
        EstadoOperador.carga => GloboColors.estadoCarga,
        EstadoOperador.transito => GloboColors.estadoTransito,
        EstadoOperador.descarga => GloboColors.estadoDescarga,
      };

  IconData get _icon => switch (estado) {
        EstadoOperador.offline => Icons.power_off_outlined,
        EstadoOperador.carga => Icons.local_shipping_outlined,
        EstadoOperador.transito => Icons.navigation_outlined,
        EstadoOperador.descarga => Icons.unarchive_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            vertical: GloboSpacing.sm, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? _color : _color.withAlpha(20),
          borderRadius: GloboRadius.buttonRadius,
          border: Border.all(
            color: isSelected ? _color : _color.withAlpha(60),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              color: isSelected ? Colors.white : _color,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              estado.label,
              style: GloboTypography.caption.copyWith(
                color: isSelected ? Colors.white : _color,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
