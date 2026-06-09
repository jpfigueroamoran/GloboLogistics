import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';

// Modelo para cada paso del cierre
class PasoCierre {
  final String id;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final bool completado;

  PasoCierre({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    this.completado = false,
  });

  PasoCierre copyWith({bool? completado}) {
    return PasoCierre(
      id: id,
      titulo: titulo,
      descripcion: descripcion,
      icono: icono,
      completado: completado ?? this.completado,
    );
  }
}

// Provider del estado del cierre mensual
final cierreMensualProvider = StateNotifierProvider<CierreMensualNotifier, List<PasoCierre>>((ref) {
  return CierreMensualNotifier();
});

class CierreMensualNotifier extends StateNotifier<List<PasoCierre>> {
  CierreMensualNotifier() : super([
    PasoCierre(
      id: 'combustible',
      titulo: 'Auditar Varianza de Combustible',
      descripcion: 'Revisar viajes con alertas de bandera roja por excesos de consumo.',
      icono: Icons.local_gas_station,
    ),
    PasoCierre(
      id: 'tco',
      titulo: 'Revisar TCO de Flota',
      descripcion: 'Analizar el Costo Total de Propiedad de este mes comparado con el presupuesto.',
      icono: Icons.insights,
    ),
    PasoCierre(
      id: 'facturas',
      titulo: 'Validar Facturas y CxC',
      descripcion: 'Verificar facturas emitidas a clientes y cartas porte asociadas.',
      icono: Icons.receipt_long,
    ),
    PasoCierre(
      id: 'mantenimiento',
      titulo: 'Cierre de Mantenimiento',
      descripcion: 'Confirmar que todas las órdenes preventivas del mes fueron completadas.',
      icono: Icons.build,
    ),
  ]);

  void togglePaso(String id) {
    state = state.map((p) {
      if (p.id == id) {
        return p.copyWith(completado: !p.completado);
      }
      return p;
    }).toList();
  }

  void marcarTodosCompletados() {
    state = state.map((p) => p.copyWith(completado: true)).toList();
  }
}

class CierreMensualPage extends ConsumerWidget {
  const CierreMensualPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pasos = ref.watch(cierreMensualProvider);
    final todosCompletados = pasos.every((p) => p.completado);
    final progreso = pasos.where((p) => p.completado).length / pasos.length;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GloboSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Roadmap de Cierre Mensual',
              style: GloboTypography.headlineLarge,
            ),
            const SizedBox(height: GloboSpacing.sm),
            Text(
              'Completa estas tareas operativas antes de generar el reporte final para el Administrador.',
              style: GloboTypography.bodyLarge.copyWith(color: GloboColors.textSecondary),
            ),
            const SizedBox(height: GloboSpacing.xl),
            
            // Tarjeta de Progreso
            Container(
              padding: const EdgeInsets.all(GloboSpacing.lg),
              decoration: BoxDecoration(
                color: GloboColors.surface,
                borderRadius: GloboRadius.cardRadius,
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progreso del Cierre',
                        style: GloboTypography.titleLarge,
                      ),
                      Text(
                        '${(progreso * 100).toInt()}%',
                        style: GloboTypography.headlineMedium.copyWith(color: GloboColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: GloboSpacing.md),
                  LinearProgressIndicator(
                    value: progreso,
                    backgroundColor: GloboColors.divider,
                    color: todosCompletados ? GloboColors.success : GloboColors.primary,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GloboSpacing.xl),

            // Lista de Tareas
            ...pasos.map((paso) => _PasoCard(paso: paso)).toList(),

            const SizedBox(height: GloboSpacing.xl),

            // Botón Generar Reporte
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: todosCompletados ? GloboColors.success : GloboColors.steelGray,
                  shape: RoundedRectangleBorder(borderRadius: GloboRadius.buttonRadius),
                ),
                onPressed: todosCompletados ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reporte de cierre mensual generado y enviado al Administrador.')),
                  );
                } : null,
                icon: const Icon(Icons.send),
                label: Text(
                  todosCompletados ? 'Generar Reporte Mensual' : 'Completa las tareas para continuar',
                  style: GloboTypography.titleMedium.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasoCard extends ConsumerWidget {
  final PasoCierre paso;

  const _PasoCard({required this.paso});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: GloboSpacing.md),
      decoration: BoxDecoration(
        color: paso.completado ? GloboColors.success.withAlpha(20) : GloboColors.surface,
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(
          color: paso.completado ? GloboColors.success : GloboColors.divider,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: GloboSpacing.lg, vertical: GloboSpacing.sm),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: paso.completado ? GloboColors.success : GloboColors.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(
            paso.completado ? Icons.check : paso.icono,
            color: paso.completado ? Colors.white : GloboColors.primary,
          ),
        ),
        title: Text(
          paso.titulo,
          style: GloboTypography.titleMedium.copyWith(
            decoration: paso.completado ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(paso.descripcion, style: GloboTypography.bodyMedium),
        trailing: Checkbox(
          value: paso.completado,
          activeColor: GloboColors.success,
          onChanged: (_) {
            ref.read(cierreMensualProvider.notifier).togglePaso(paso.id);
          },
        ),
        onTap: () {
          ref.read(cierreMensualProvider.notifier).togglePaso(paso.id);
        },
      ),
    );
  }
}
