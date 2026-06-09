import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../core/services/factura_pdf_service.dart';
import '../../../../domain/entities/factura_cliente.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/dashboard_provider.dart';
import '../providers/factura_cliente_provider.dart';

class HistorialViajesPage extends ConsumerStatefulWidget {
  const HistorialViajesPage({super.key});

  @override
  ConsumerState<HistorialViajesPage> createState() => _HistorialViajesPageState();
}

class _HistorialViajesPageState extends ConsumerState<HistorialViajesPage> {
  String _filtroOperador = 'Todos';
  String _filtroUnidad = 'Todas';

  @override
  Widget build(BuildContext context) {
    final viajesSP = ref.watch(viajesCompletadosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HISTORIAL Y TCO',
              style: GloboTypography.labelSmall.copyWith(
                letterSpacing: 2,
                color: GloboColors.textTertiary,
              ),
            ),
            const Text('Auditoría Retrospectiva y Detección de Fugas'),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Exportar CSV'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generando reporte CSV...')),
              );
            },
          ),
          const SizedBox(width: GloboSpacing.md),
        ],
      ),
      body: viajesSP.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (viajes) {
          if (viajes.isEmpty) {
            return const Center(child: Text('No hay viajes completados.'));
          }

          // Aplicar filtros
          var filtrados = viajes;
          if (_filtroOperador != 'Todos') {
            filtrados = filtrados.where((v) => v.operadorId == _filtroOperador).toList();
          }
          if (_filtroUnidad != 'Todas') {
            filtrados = filtrados.where((v) => v.unidadId == _filtroUnidad).toList();
          }

          final facturas = ref.watch(facturasProvider).valueOrNull ?? [];

          return Column(
            children: [
              _TopOffendersPanel(viajes: viajes),
              _FiltrosPanel(
                viajes: viajes,
                operadorSeleccionado: _filtroOperador,
                unidadSeleccionada: _filtroUnidad,
                onOperadorChanged: (val) => setState(() => _filtroOperador = val!),
                onUnidadChanged: (val) => setState(() => _filtroUnidad = val!),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(GloboSpacing.md),
                  itemCount: filtrados.length,
                  itemBuilder: (ctx, i) {
                    final factura = facturas.cast<FacturaCliente?>()
                        .firstWhere(
                          (f) => f?.viajeId == filtrados[i].id,
                          orElse: () => null,
                        );
                    return _HistorialRow(viaje: filtrados[i], factura: factura);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Top Offenders Panel ───────────────────────────────────────────────────────

class _TopOffendersPanel extends StatelessWidget {
  final List<Viaje> viajes;

  const _TopOffendersPanel({required this.viajes});

  @override
  Widget build(BuildContext context) {
    if (viajes.isEmpty) return const SizedBox.shrink();

    // Calcular la ruta con más fuga (mayor varianza promedio)
    final rutas = <String, List<double>>{};
    for (var v in viajes) {
      if (v.varianzaCombustible != null) {
        final key = '${v.origenDescripcion} - ${v.destinoDescripcion}';
        rutas.putIfAbsent(key, () => []).add(v.varianzaCombustible!);
      }
    }

    String rutaMasFuga = 'N/A';
    double maxVarianzaRuta = 0.0;
    rutas.forEach((ruta, varianzas) {
      final prom = varianzas.reduce((a, b) => a + b) / varianzas.length;
      if (prom > maxVarianzaRuta) {
        maxVarianzaRuta = prom;
        rutaMasFuga = ruta;
      }
    });

    // Unidad con peor rendimiento km/L
    // distanciaKm ≈ litrosTelemetria × 3.5 (rendimiento base flota — mismo factor que CF recalcularTco)
    final rendPorUnidad = <String, List<double>>{};
    for (final v in viajes) {
      if (v.litrosCargados > 0 && v.litrosConsumiidosTelemetria > 0) {
        final km = v.litrosConsumiidosTelemetria * 3.5;
        rendPorUnidad.putIfAbsent(v.unidadId, () => []).add(km / v.litrosCargados);
      }
    }
    String peorUnidad = 'Sin datos';
    String peorRendStr = '—';
    if (rendPorUnidad.isNotEmpty) {
      double minRend = double.infinity;
      rendPorUnidad.forEach((uid, rends) {
        final prom = rends.reduce((a, b) => a + b) / rends.length;
        if (prom < minRend) {
          minRend = prom;
          peorUnidad = uid;
        }
      });
      if (minRend.isFinite) peorRendStr = '${minRend.toStringAsFixed(1)} Km/L';
    }

    return Container(
      padding: const EdgeInsets.all(GloboSpacing.md),
      margin: const EdgeInsets.all(GloboSpacing.md),
      decoration: BoxDecoration(
        color: GloboColors.surface,
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(color: GloboColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: GloboColors.warning),
              const SizedBox(width: GloboSpacing.sm),
              Text('Top Offenders (Áreas de Oportunidad)', style: GloboTypography.titleMedium),
            ],
          ),
          const SizedBox(height: GloboSpacing.md),
          Row(
            children: [
              Expanded(
                child: _OffenderCard(
                  titulo: 'Ruta con Mayor Fuga Promedio',
                  valor: rutaMasFuga,
                  metrica: '${(maxVarianzaRuta * 100).toStringAsFixed(1)}% Varianza',
                  color: GloboColors.warning,
                ),
              ),
              const SizedBox(width: GloboSpacing.md),
              Expanded(
                child: _OffenderCard(
                  titulo: 'Unidad con Peor Rendimiento',
                  valor: peorUnidad,
                  metrica: peorRendStr,
                  color: GloboColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OffenderCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String metrica;
  final Color color;

  const _OffenderCard({
    required this.titulo,
    required this.valor,
    required this.metrica,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GloboSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: GloboRadius.buttonRadius,
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: GloboTypography.labelSmall),
          const SizedBox(height: 4),
          Text(valor, style: GloboTypography.titleMedium, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(metrica, style: GloboTypography.labelLarge.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Filtros Panel ─────────────────────────────────────────────────────────────

class _FiltrosPanel extends StatelessWidget {
  final List<Viaje> viajes;
  final String operadorSeleccionado;
  final String unidadSeleccionada;
  final ValueChanged<String?> onOperadorChanged;
  final ValueChanged<String?> onUnidadChanged;

  const _FiltrosPanel({
    required this.viajes,
    required this.operadorSeleccionado,
    required this.unidadSeleccionada,
    required this.onOperadorChanged,
    required this.onUnidadChanged,
  });

  @override
  Widget build(BuildContext context) {
    final operadores = ['Todos', ...viajes.map((v) => v.operadorId).toSet()];
    final unidades = ['Todas', ...viajes.map((v) => v.unidadId).toSet()];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18, color: GloboColors.textTertiary),
          const SizedBox(width: GloboSpacing.sm),
          const Text('Filtros: ', style: GloboTypography.bodyMedium),
          const SizedBox(width: GloboSpacing.md),
          DropdownButton<String>(
            value: operadorSeleccionado,
            items: operadores.map((op) => DropdownMenuItem(value: op, child: Text(op == 'Todos' ? 'Todos los Operadores' : op))).toList(),
            onChanged: onOperadorChanged,
            underline: const SizedBox(),
          ),
          const SizedBox(width: GloboSpacing.lg),
          DropdownButton<String>(
            value: unidadSeleccionada,
            items: unidades.map((u) => DropdownMenuItem(value: u, child: Text(u == 'Todas' ? 'Todas las Unidades' : u))).toList(),
            onChanged: onUnidadChanged,
            underline: const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ── Fila de Historial ─────────────────────────────────────────────────────────

class _HistorialRow extends StatelessWidget {
  final Viaje viaje;
  final FacturaCliente? factura;

  const _HistorialRow({required this.viaje, this.factura});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM yyyy, HH:mm');
    final finStr = viaje.fechaFin != null ? format.format(viaje.fechaFin!) : 'N/A';
    
    // Km estimado: litrosTelemetria × 3.5 km/L base (mismo factor que CF recalcularTco)
    final litros = viaje.litrosCargados;
    final kmEstimado = viaje.litrosConsumiidosTelemetria > 0
        ? viaje.litrosConsumiidosTelemetria * 3.5
        : 0.0;
    final rendimiento = (litros > 0 && kmEstimado > 0)
        ? (kmEstimado / litros).toStringAsFixed(1)
        : 'N/A';
    
    final varianza = viaje.varianzaCombustible;
    final varianzaStr = varianza != null ? '${(varianza * 100).toStringAsFixed(1)}%' : 'N/A';
    final isAlerta = varianza != null && varianza > 0.05;

    return Card(
      margin: const EdgeInsets.only(bottom: GloboSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(viaje.id, style: GloboTypography.labelSmall),
                      Text('${viaje.origenDescripcion} → ${viaje.destinoDescripcion}', style: GloboTypography.titleMedium),
                      Text(finStr, style: GloboTypography.caption),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Operador', style: GloboTypography.labelSmall),
                      Text(viaje.operadorId, style: GloboTypography.bodyMedium),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unidad', style: GloboTypography.labelSmall),
                      Text(viaje.unidadId, style: GloboTypography.bodyMedium),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rendimiento', style: GloboTypography.labelSmall),
                      Text('$rendimiento Km/L', style: GloboTypography.monoData),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Varianza', style: GloboTypography.labelSmall),
                      Text(
                        varianzaStr,
                        style: GloboTypography.monoData.copyWith(
                          color: isAlerta ? GloboColors.error : GloboColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TCO Final', style: GloboTypography.labelSmall),
                      Text('\$${viaje.tco.total.toStringAsFixed(2)}', style: GloboTypography.titleLarge),
                    ],
                  ),
                ),
              ],
            ),
            if (viaje.justificacionVarianza != null && viaje.justificacionVarianza!.isNotEmpty) ...[
              const SizedBox(height: GloboSpacing.sm),
              const Divider(),
              const SizedBox(height: GloboSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 16, color: GloboColors.info),
                  const SizedBox(width: GloboSpacing.sm),
                  Expanded(
                    child: Text(
                      'Justificación del Operador: ${viaje.justificacionVarianza}',
                      style: GloboTypography.bodyMedium.copyWith(color: GloboColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
            if (factura != null) ...[
              const SizedBox(height: GloboSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: ActionChip(
                  avatar: Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: factura!.estatus == EstatusFactura.cobrada
                        ? GloboColors.success
                        : GloboColors.warning,
                  ),
                  label: Text(
                    'Ver Factura ${factura!.numeroFactura}',
                    style: GloboTypography.labelSmall,
                  ),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _FacturaDialog(factura: factura!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Diálogo de Factura ────────────────────────────────────────────────────────

class _FacturaDialog extends StatelessWidget {
  final FacturaCliente factura;
  const _FacturaDialog({required this.factura});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final moneyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final ahora = DateTime.now();
    final dias = factura.diasVencimiento(ahora);

    Color estatusColor;
    switch (factura.estatus) {
      case EstatusFactura.cobrada:
        estatusColor = GloboColors.success;
        break;
      case EstatusFactura.vencida:
        estatusColor = GloboColors.error;
        break;
      case EstatusFactura.cancelada:
        estatusColor = GloboColors.textTertiary;
        break;
      case EstatusFactura.pendiente:
        estatusColor = GloboColors.warning;
        break;
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long_outlined),
          const SizedBox(width: GloboSpacing.sm),
          Text(factura.numeroFactura),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogRow(label: 'Cliente', value: factura.clienteNombre),
            _DialogRow(label: 'Emisión', value: fmt.format(factura.fechaEmision)),
            _DialogRow(label: 'Vencimiento', value: fmt.format(factura.fechaVencimiento)),
            _DialogRow(
              label: 'Días',
              value: dias >= 0 ? '+$dias días vigente' : '${-dias} días vencida',
              valueColor: dias >= 0 ? GloboColors.success : GloboColors.error,
            ),
            _DialogRow(label: 'Monto', value: moneyFmt.format(factura.monto)),
            if (factura.montoCobrado != null)
              _DialogRow(
                label: 'Cobrado',
                value: moneyFmt.format(factura.montoCobrado!),
                valueColor: GloboColors.success,
              ),
            if (factura.fechaCobro != null)
              _DialogRow(label: 'Fecha Cobro', value: fmt.format(factura.fechaCobro!)),
            const SizedBox(height: GloboSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: GloboSpacing.md, vertical: GloboSpacing.xs),
                decoration: BoxDecoration(
                  color: estatusColor.withAlpha(30),
                  borderRadius: GloboRadius.buttonRadius,
                  border: Border.all(color: estatusColor.withAlpha(100)),
                ),
                child: Text(
                  factura.estatus.name.toUpperCase(),
                  style: GloboTypography.labelSmall.copyWith(color: estatusColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('Exportar PDF'),
          onPressed: () => FacturaPdfService.exportar(factura),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DialogRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GloboTypography.labelSmall),
          ),
          Expanded(
            child: Text(
              value,
              style: GloboTypography.bodyMedium.copyWith(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
