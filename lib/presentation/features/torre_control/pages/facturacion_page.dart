import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/factura_cliente.dart';
import '../providers/cxc_aging_provider.dart';
import '../providers/factura_cliente_provider.dart';
import 'package:printing/printing.dart';
import '../../../../core/utils/pdf_generator.dart';

class FacturacionPage extends ConsumerStatefulWidget {
  const FacturacionPage({super.key});

  @override
  ConsumerState<FacturacionPage> createState() => _FacturacionPageState();
}

class _FacturacionPageState extends ConsumerState<FacturacionPage> {
  String _filtroBusqueda = '';
  EstatusFactura? _filtroEstatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Header / KPIs Aging ───────────────────────────────────────────
        const _CxcAgingHeader(),
        const Divider(height: 1),

        // ── 2. Controles de Filtro ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(GloboSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por folio o cliente...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: GloboRadius.buttonRadius,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() => _filtroBusqueda = v),
                ),
              ),
              const SizedBox(width: GloboSpacing.md),
              DropdownButton<EstatusFactura?>(
                value: _filtroEstatus,
                hint: const Text('Todos los estatus'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los estatus')),
                  ...EstatusFactura.values.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.name.toUpperCase()),
                      )),
                ],
                onChanged: (v) => setState(() => _filtroEstatus = v),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── 3. Lista de Facturas ───────────────────────────────────────────
        Expanded(
          child: _FacturasList(
            busqueda: _filtroBusqueda,
            filtroEstatus: _filtroEstatus,
          ),
        ),
      ],
    );
  }
}

class _CxcAgingHeader extends ConsumerWidget {
  const _CxcAgingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aging = ref.watch(cxcAgingProvider);
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _AgingCard(
            title: 'Corriente',
            amount: fmt.format(aging[BucketAging.corriente] ?? 0),
            color: GloboColors.successAccent,
          ),
          _AgingCard(
            title: '1 - 30 días',
            amount: fmt.format(aging[BucketAging.vencido30] ?? 0),
            color: GloboColors.warningAccent,
          ),
          _AgingCard(
            title: '31 - 60 días',
            amount: fmt.format(aging[BucketAging.vencido60] ?? 0),
            color: Colors.orange,
          ),
          _AgingCard(
            title: '61 - 90 días',
            amount: fmt.format(aging[BucketAging.vencido90] ?? 0),
            color: Colors.deepOrange,
          ),
          _AgingCard(
            title: '+90 días',
            amount: fmt.format(aging[BucketAging.vencido90mas] ?? 0),
            color: GloboColors.error,
          ),
        ],
      ),
    );
  }
}

class _AgingCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;

  const _AgingCard({
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: GloboSpacing.xs),
        padding: const EdgeInsets.all(GloboSpacing.sm),
        decoration: BoxDecoration(
          color: GloboColors.surface,
          borderRadius: GloboRadius.cardRadius,
          border: Border.all(color: color.withAlpha(50)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Text(title,
                style: GloboTypography.caption.copyWith(color: GloboColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              amount,
              style: GloboTypography.titleMedium.copyWith(color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FacturasList extends ConsumerWidget {
  final String busqueda;
  final EstatusFactura? filtroEstatus;

  const _FacturasList({
    required this.busqueda,
    required this.filtroEstatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facturasAsync = ref.watch(facturasProvider);
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return facturasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (facturas) {
        var filtradas = facturas.where((f) {
          if (filtroEstatus != null && f.estatus != filtroEstatus) {
            return false;
          }
          if (busqueda.isNotEmpty) {
            final q = busqueda.toLowerCase();
            return f.numeroFactura.toLowerCase().contains(q) ||
                f.clienteNombre.toLowerCase().contains(q);
          }
          return true;
        }).toList();

        filtradas.sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

        if (filtradas.isEmpty) {
          return const Center(child: Text('No se encontraron facturas.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(GloboSpacing.md),
          itemCount: filtradas.length,
          separatorBuilder: (_, __) => const SizedBox(height: GloboSpacing.sm),
          itemBuilder: (context, index) {
            final f = filtradas[index];
            return _FacturaItem(factura: f, fmt: fmt);
          },
        );
      },
    );
  }
}

class _FacturaItem extends ConsumerWidget {
  final FacturaCliente factura;
  final NumberFormat fmt;

  const _FacturaItem({required this.factura, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmtFecha = DateFormat('dd/MM/yyyy');
    final esVencida = factura.estatus == EstatusFactura.vencida;
    final esCobrada = factura.estatus == EstatusFactura.cobrada;

    final colorEstatus = switch (factura.estatus) {
      EstatusFactura.pendiente => GloboColors.warningAccent,
      EstatusFactura.cobrada => GloboColors.successAccent,
      EstatusFactura.vencida => GloboColors.error,
      EstatusFactura.cancelada => GloboColors.steelGray,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(color: Colors.grey.withAlpha(100)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Row(
          children: [
            // Estatus
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorEstatus.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorEstatus),
              ),
              child: Text(
                factura.estatusLabel,
                style: GloboTypography.caption.copyWith(
                  color: colorEstatus,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: GloboSpacing.md),
            // Detalles principales
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(factura.numeroFactura, style: GloboTypography.titleMedium),
                  Text(factura.clienteNombre, style: GloboTypography.bodyMedium),
                  if (factura.cartaPorteUuid != null)
                    Text('Carta Porte: ${factura.cartaPorteUuid}',
                        style: GloboTypography.caption.copyWith(color: GloboColors.textTertiary)),
                ],
              ),
            ),
            // Montos
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmt.format(factura.monto), style: GloboTypography.monoData.copyWith(fontSize: 16)),
                  if (esCobrada)
                    Text('Pagado: ${fmt.format(factura.montoCobrado ?? factura.monto)}',
                        style: GloboTypography.caption.copyWith(color: GloboColors.successAccent)),
                ],
              ),
            ),
            const SizedBox(width: GloboSpacing.md),
            // Fechas
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Emisión: ${fmtFecha.format(factura.fechaEmision)}',
                      style: GloboTypography.caption),
                  Text(
                    'Vence: ${fmtFecha.format(factura.fechaVencimiento)}',
                    style: GloboTypography.caption.copyWith(
                      color: esVencida ? GloboColors.error : GloboColors.textPrimary,
                      fontWeight: esVencida ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GloboSpacing.md),
            // Acciones
            Column(
              children: [
                if (factura.estatus == EstatusFactura.pendiente || factura.estatus == EstatusFactura.vencida)
                  Padding(
                    padding: const EdgeInsets.only(bottom: GloboSpacing.xs),
                    child: ElevatedButton.icon(
                      onPressed: () => _registrarCobro(context, ref, factura),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Cobrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GloboColors.successAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final pdfData = await PdfGenerator.generateFacturaPdf(factura);
                    await Printing.layoutPdf(
                      onLayout: (format) => pdfData,
                      name: 'Factura_${factura.numeroFactura}.pdf',
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Ver PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _registrarCobro(BuildContext context, WidgetRef ref, FacturaCliente factura) async {
    final scaffold = ScaffoldMessenger.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Cobro'),
        content: Text('¿Confirmas que la factura ${factura.numeroFactura} por ${fmt.format(factura.monto)} ha sido cobrada en su totalidad?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: GloboColors.successAccent, foregroundColor: Colors.white),
            child: const Text('Confirmar Cobro'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ref.read(registrarCobroProvider)(
        factura.id,
        factura.monto,
        DateTime.now(),
      );
      res.fold(
        (l) => scaffold.showSnackBar(SnackBar(content: Text('Error: $l'), backgroundColor: GloboColors.error)),
        (r) => scaffold.showSnackBar(const SnackBar(content: Text('Cobro registrado con éxito.'), backgroundColor: GloboColors.successAccent)),
      );
    }
  }
}
