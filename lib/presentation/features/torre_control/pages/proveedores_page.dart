import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/cuenta_por_cobrar.dart'; // NivelRiesgo
import '../../../../domain/entities/cuenta_por_pagar.dart';
import '../../../../domain/entities/factura_cliente.dart'; // BucketAging, EstatusFactura
import '../../../../domain/entities/factura_proveedor.dart';
import '../../../../domain/entities/item_inventario.dart';
import '../providers/factura_cliente_provider.dart';
import '../providers/factura_proveedor_provider.dart';
import '../providers/inventario_provider.dart';
import '../widgets/subir_factura_proveedor_dialog.dart';

class ProveedoresPage extends ConsumerStatefulWidget {
  const ProveedoresPage({super.key});

  @override
  ConsumerState<ProveedoresPage> createState() => _ProveedoresPageState();
}

class _ProveedoresPageState extends ConsumerState<ProveedoresPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProveedoresTabBar(controller: _tabController),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _CxPTab(),
              _InventarioTab(),
              _CartaPorteTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── TabBar ────────────────────────────────────────────────────────────────────

class _ProveedoresTabBar extends StatelessWidget {
  final TabController controller;
  const _ProveedoresTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GloboColors.surface,
      child: TabBar(
        controller: controller,
        labelColor: GloboColors.primary,
        unselectedLabelColor: GloboColors.textTertiary,
        indicatorColor: GloboColors.accentBright,
        indicatorWeight: 3,
        labelStyle: GloboTypography.labelLarge,
        tabs: const [
          Tab(icon: Icon(Icons.payment_outlined,   size: 18), text: 'Cuentas x Pagar'),
          Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Inventario'),
          Tab(icon: Icon(Icons.article_outlined,   size: 18), text: 'Carta Porte'),
        ],
      ),
    );
  }
}

// ── TAB 1: Cuentas por Pagar ──────────────────────────────────────────────────

class _CxPTab extends ConsumerWidget {
  const _CxPTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facturasAsync  = ref.watch(facturasProveedorProvider);
    final totalPendiente = ref.watch(cxpTotalPendienteProvider);
    final vencidas       = ref.watch(facturasProveedorVencidasCountProvider);
    final gastosMes      = ref.watch(gastosPagadosMesProvider);
    final cxp            = ref.watch(cxpProvider);
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final ahora = DateTime.now();

    return facturasAsync.when(
      loading: () => const _ShimmerTabContent(),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (_) => Column(
        children: [
          // KPI strip
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
            child: Row(children: [
              _KpiCard(
                label: 'Total por Pagar',
                value: fmt.format(totalPendiente),
                icon: Icons.account_balance_wallet_outlined,
                color: GloboColors.error,
              ),
              const SizedBox(width: GloboSpacing.md),
              _KpiCard(
                label: 'Facturas Vencidas',
                value: '$vencidas',
                icon: Icons.warning_amber_outlined,
                color: vencidas > 0 ? GloboColors.warning : GloboColors.successAccent,
              ),
              const SizedBox(width: GloboSpacing.md),
              _KpiCard(
                label: 'Pagado este Mes',
                value: fmt.format(gastosMes),
                icon: Icons.check_circle_outline,
                color: GloboColors.successAccent,
              ),
            ]),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.lg, vertical: GloboSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AgingLegend(),
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SubirFacturaProveedorDialog(),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Registrar Gasto / Factura'),
                  style: FilledButton.styleFrom(
                    backgroundColor: GloboColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: GloboRadius.buttonRadius),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          _CxPTableHeader(),
          const Divider(height: 0),
          Expanded(
            child: cxp.isEmpty
                ? const Center(child: Text('Sin cuentas pendientes.'))
                : ListView.separated(
                    itemCount: cxp.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 0, color: GloboColors.divider),
                    itemBuilder: (_, i) =>
                        _CxPRow(cuenta: cxp[i], ahora: ahora, fmt: fmt),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgingLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Antigüedad: ', style: GloboTypography.labelSmall),
        const SizedBox(width: GloboSpacing.sm),
        const _LegendChip(color: Color(0xFF4CAF50), label: 'Corriente'),
        const _LegendChip(color: Color(0xFFFFB300), label: '1-30d'),
        const _LegendChip(color: Color(0xFFFF7043), label: '31-60d'),
        const _LegendChip(color: Color(0xFFE53935), label: '61-90d'),
        const _LegendChip(color: Color(0xFF7B1FA2), label: '+90d'),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: GloboSpacing.sm),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GloboTypography.caption),
      ]),
    );
  }
}

class _CxPTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      child: Row(children: [
        Expanded(flex: 3, child: Text('Proveedor', style: GloboTypography.labelSmall)),
        Expanded(flex: 2, child: Text('Corriente',  style: GloboTypography.labelSmall, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('1-30 d',     style: GloboTypography.labelSmall, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('31-60 d',    style: GloboTypography.labelSmall, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('61-90 d',    style: GloboTypography.labelSmall, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('+90 d',      style: GloboTypography.labelSmall, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('Total',      style: GloboTypography.labelSmall, textAlign: TextAlign.right)),
        const SizedBox(width: 28),
      ]),
    );
  }
}

class _CxPRow extends ConsumerStatefulWidget {
  final CuentaPorPagar cuenta;
  final DateTime ahora;
  final NumberFormat fmt;
  const _CxPRow({required this.cuenta, required this.ahora, required this.fmt});

  @override
  ConsumerState<_CxPRow> createState() => _CxPRowState();
}

class _CxPRowState extends ConsumerState<_CxPRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cuenta = widget.cuenta;
    final ahora = widget.ahora;
    final fmt = widget.fmt;
    final nivel = cuenta.nivelRiesgo(ahora);
    final bg = switch (nivel) {
      NivelRiesgo.critico  => GloboColors.error.withAlpha(10),
      NivelRiesgo.atencion => GloboColors.warning.withAlpha(10),
      NivelRiesgo.ok       => Colors.transparent,
    };

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            color: bg,
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
            child: Row(children: [
              Expanded(flex: 3, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: GloboColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(cuenta.proveedorNombre, style: GloboTypography.bodyMedium, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(cuenta.tipoProveedor.label, style: GloboTypography.caption),
                  ),
                ],
              )),
              _AgingCell(monto: cuenta.montoEnBucket(BucketAging.corriente, ahora),  color: const Color(0xFF4CAF50), fmt: fmt),
              _AgingCell(monto: cuenta.montoEnBucket(BucketAging.vencido30, ahora),  color: const Color(0xFFFFB300), fmt: fmt),
              _AgingCell(monto: cuenta.montoEnBucket(BucketAging.vencido60, ahora),  color: const Color(0xFFFF7043), fmt: fmt),
              _AgingCell(monto: cuenta.montoEnBucket(BucketAging.vencido90, ahora),  color: const Color(0xFFE53935), fmt: fmt),
              _AgingCell(monto: cuenta.montoEnBucket(BucketAging.vencido90mas, ahora), color: const Color(0xFF7B1FA2), fmt: fmt),
              Expanded(flex: 2, child: Text(
                fmt.format(cuenta.montoPendienteTotal),
                style: GloboTypography.monoData.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              )),
              SizedBox(width: 28, child: nivel != NivelRiesgo.ok
                  ? Icon(Icons.warning_amber_rounded,
                      color: nivel == NivelRiesgo.critico
                          ? GloboColors.error : GloboColors.warning,
                      size: 18)
                  : null),
            ]),
          ),
        ),
        if (_expanded)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
            padding: const EdgeInsets.fromLTRB(GloboSpacing.xl, GloboSpacing.sm, GloboSpacing.md, GloboSpacing.sm),
            child: Column(
              children: cuenta.facturasPendientes.map((f) {
                final fmtFecha = DateFormat('dd/MM/yyyy');
                final esVencida = f.estatus == EstatusFacturaProveedor.vencida;
                return Padding(
                  padding: const EdgeInsets.only(bottom: GloboSpacing.xs),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (esVencida ? GloboColors.error : GloboColors.warningAccent).withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: esVencida ? GloboColors.error : GloboColors.warningAccent),
                        ),
                        child: Text(
                          f.estatus == EstatusFacturaProveedor.vencida ? 'VENCIDA' : 'PENDIENTE',
                          style: GloboTypography.caption.copyWith(
                            color: esVencida ? GloboColors.error : GloboColors.warningAccent,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(width: GloboSpacing.md),
                      Expanded(
                        flex: 2,
                        child: Text('Folio: ${f.numeroFactura}', style: GloboTypography.bodyMedium),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('Emisión: ${fmtFecha.format(f.fechaEmision)}', style: GloboTypography.caption),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Vence: ${fmtFecha.format(f.fechaVencimiento)}',
                          style: GloboTypography.caption.copyWith(
                            color: esVencida ? GloboColors.error : GloboColors.textPrimary,
                            fontWeight: esVencida ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(fmt.format(f.monto), style: GloboTypography.monoData, textAlign: TextAlign.right),
                      ),
                      const SizedBox(width: GloboSpacing.md),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton(
                          onPressed: () => _registrarPago(context, ref, f),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GloboColors.successAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Pagar', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _registrarPago(BuildContext context, WidgetRef ref, FacturaProveedor factura) async {
    final fmt = widget.fmt;
    final scaffold = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Pago a Proveedor'),
        content: Text('¿Confirmas el pago de la factura ${factura.numeroFactura} por ${fmt.format(factura.monto)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: GloboColors.successAccent, foregroundColor: Colors.white),
            child: const Text('Confirmar Pago'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ref.read(registrarPagoProveedorProvider)(
        factura.id,
        factura.monto,
        DateTime.now(),
      );
      if (!mounted) return;
      res.fold(
        (l) => scaffold.showSnackBar(SnackBar(content: Text('Error: $l'), backgroundColor: GloboColors.error)),
        (r) => scaffold.showSnackBar(const SnackBar(content: Text('Pago registrado con éxito.'), backgroundColor: GloboColors.successAccent)),
      );
    }
  }
}

class _AgingCell extends StatelessWidget {
  final double monto;
  final Color color;
  final NumberFormat fmt;
  const _AgingCell({required this.monto, required this.color, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Text(
        monto > 0 ? fmt.format(monto) : '—',
        style: GloboTypography.monoData.copyWith(
          color: monto > 0 ? color : GloboColors.textTertiary,
          fontSize: 11,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

// ── TAB 2: Inventario ─────────────────────────────────────────────────────────

class _InventarioTab extends ConsumerWidget {
  const _InventarioTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventarioAsync = ref.watch(inventarioProvider);
    final bajoStock       = ref.watch(itemsBajoStockCountProvider);
    final valorTotal      = ref.watch(valorTotalInventarioProvider);
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return inventarioAsync.when(
      loading: () => const _ShimmerTabContent(),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (items) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
            child: Row(children: [
              _KpiCard(
                label: 'Ítems Registrados',
                value: '${items.length}',
                icon: Icons.inventory_outlined,
                color: GloboColors.accentBright,
              ),
              const SizedBox(width: GloboSpacing.md),
              _KpiCard(
                label: 'Bajo Stock Mínimo',
                value: '$bajoStock',
                icon: Icons.warning_amber_outlined,
                color: bajoStock > 0 ? GloboColors.error : GloboColors.successAccent,
              ),
              const SizedBox(width: GloboSpacing.md),
              _KpiCard(
                label: 'Valor Total Inventario',
                value: fmt.format(valorTotal),
                icon: Icons.monetization_on_outlined,
                color: GloboColors.steelGray,
              ),
            ]),
          ),
          const Divider(height: 0),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Sin ítems registrados.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(GloboSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: GloboSpacing.sm),
                    itemBuilder: (_, i) =>
                        _ItemCard(item: items[i], fmt: fmt),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final ItemInventario item;
  final NumberFormat fmt;
  const _ItemCard({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = item.pctStock.clamp(0.0, 1.0);
    final Color barColor;
    final Color borderColor;
    if (item.esBajoStock) {
      barColor    = GloboColors.error;
      borderColor = GloboColors.error.withAlpha(80);
    } else if (pct < 1.3) {
      barColor    = GloboColors.warning;
      borderColor = GloboColors.warning.withAlpha(50);
    } else {
      barColor    = GloboColors.successAccent;
      borderColor = GloboColors.divider;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Row(children: [
          // Icono categoría
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: barColor.withAlpha(20),
              borderRadius: GloboRadius.buttonRadius,
            ),
            child: Icon(_categoriaIcon(item.categoria), color: barColor, size: 22),
          ),
          const SizedBox(width: GloboSpacing.md),
          // Nombre + categoría
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.nombre, style: GloboTypography.titleMedium),
              Text(item.categoria.label, style: GloboTypography.caption),
            ],
          )),
          // Barra de stock
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: barColor.withAlpha(25),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.stockActual.toStringAsFixed(item.unidadMedida == UnidadMedida.piezas ? 0 : 1)} '
                '/ ${item.stockMinimo.toStringAsFixed(0)} ${item.unidadMedida.label}',
                style: GloboTypography.caption.copyWith(color: barColor),
              ),
            ],
          )),
          const SizedBox(width: GloboSpacing.lg),
          // Precio + valor
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(item.precioUnitario),
                  style: GloboTypography.caption),
              Text(fmt.format(item.valorTotal),
                  style: GloboTypography.monoData.copyWith(
                      fontWeight: FontWeight.w600)),
            ],
          )),
          // Alerta bajo stock
          const SizedBox(width: GloboSpacing.sm),
          SizedBox(width: 24, child: item.esBajoStock
              ? Tooltip(
                  message: 'Stock por debajo del mínimo',
                  child: Icon(Icons.warning_amber_rounded,
                      color: GloboColors.error, size: 18),
                )
              : null),
          const SizedBox(width: GloboSpacing.md),
          FilledButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Ajustar'),
            style: FilledButton.styleFrom(
              backgroundColor: GloboColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.md, vertical: 8),
            ),
            onPressed: () => _mostrarDialogoAjuste(context, ref),
          ),
        ]),
      ),
    );
  }

  void _mostrarDialogoAjuste(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    bool sumar = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Ajustar Stock'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Actual: ${item.stockActual} ${item.unidadMedida.label}'),
                const SizedBox(height: GloboSpacing.md),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Entrada (+)'),
                      selected: sumar,
                      onSelected: (v) => setState(() => sumar = true),
                      selectedColor: GloboColors.successAccent.withAlpha(50),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Salida (-)'),
                      selected: !sumar,
                      onSelected: (v) => setState(() => sumar = false),
                      selectedColor: GloboColors.error.withAlpha(50),
                    ),
                  ],
                ),
                const SizedBox(height: GloboSpacing.md),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cantidad a ${sumar ? "añadir" : "retirar"}',
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final val = double.tryParse(ctrl.text);
                  if (val == null || val <= 0) return;
                  Navigator.of(ctx).pop();
                  
                  final nuevoStock = sumar ? item.stockActual + val : item.stockActual - val;
                  if (nuevoStock < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error: El stock no puede ser negativo')),
                    );
                    return;
                  }

                  final res = await ref.read(actualizarStockProvider)(item.id, nuevoStock);
                  if (!context.mounted) return;
                  res.fold(
                    (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $l'), backgroundColor: GloboColors.error)),
                    (r) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock actualizado.'), backgroundColor: GloboColors.successAccent)),
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        }
      ),
    );
  }

  IconData _categoriaIcon(CategoriaInventario cat) => switch (cat) {
    CategoriaInventario.llantas      => Icons.tire_repair_outlined,
    CategoriaInventario.refacciones  => Icons.build_circle_outlined,
    CategoriaInventario.aceites      => Icons.water_drop_outlined,
    CategoriaInventario.herramientas => Icons.construction_outlined,
    CategoriaInventario.otro         => Icons.category_outlined,
  };
}

// ── TAB 3: Carta Porte ────────────────────────────────────────────────────────

class _CartaPorteTab extends ConsumerWidget {
  const _CartaPorteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facturasAsync = ref.watch(facturasProvider);
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return facturasAsync.when(
      loading: () => const _ShimmerTabContent(),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (facturas) {
        final sinUuid = facturas
            .where((f) =>
                f.cartaPorteUuid == null &&
                (f.estatus == EstatusFactura.pendiente ||
                    f.estatus == EstatusFactura.cobrada))
            .toList();

        return Column(children: [
          _CartaPorteHeader(count: sinUuid.length),
          const Divider(height: 0),
          Expanded(
            child: sinUuid.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: GloboColors.successAccent),
                        const SizedBox(height: GloboSpacing.md),
                        Text('Todas las facturas tienen CFDI asignado.',
                            style: GloboTypography.titleMedium),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(GloboSpacing.md),
                    itemCount: sinUuid.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: GloboSpacing.sm),
                    itemBuilder: (_, i) => _CartaPorteRow(
                        factura: sinUuid[i], fmt: fmt),
                  ),
          ),
        ]);
      },
    );
  }
}

class _CartaPorteHeader extends StatelessWidget {
  final int count;
  const _CartaPorteHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GloboColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
      child: Row(children: [
        Icon(Icons.article_outlined,
            color: count > 0 ? GloboColors.warning : GloboColors.successAccent),
        const SizedBox(width: GloboSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Carta Porte SAT — CFDI 4.0',
                  style: GloboTypography.titleMedium),
              Text(
                count > 0
                    ? '$count factura(s) pendientes de asignación de UUID CFDI'
                    : 'Todas las facturas tienen UUID CFDI registrado',
                style: GloboTypography.caption.copyWith(
                  color: count > 0
                      ? GloboColors.warning
                      : GloboColors.successAccent,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _CartaPorteRow extends ConsumerWidget {
  final FacturaCliente factura;
  final NumberFormat fmt;
  const _CartaPorteRow({required this.factura, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmtFecha = DateFormat('dd/MM/yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Row(children: [
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(factura.numeroFactura, style: GloboTypography.titleMedium),
              Text(fmtFecha.format(factura.fechaEmision),
                  style: GloboTypography.caption),
            ],
          )),
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cliente', style: GloboTypography.labelSmall),
              Text(factura.clienteNombre, style: GloboTypography.bodyMedium),
            ],
          )),
          Expanded(flex: 2, child: Text(
            fmt.format(factura.monto),
            style: GloboTypography.monoData,
          )),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.sm, vertical: GloboSpacing.xs),
            decoration: BoxDecoration(
              color: GloboColors.warning.withAlpha(25),
              borderRadius: GloboRadius.buttonRadius,
            ),
            child: Text('Sin CFDI',
                style: GloboTypography.labelSmall
                    .copyWith(color: GloboColors.warning)),
          ),
          const SizedBox(width: GloboSpacing.md),
          FilledButton.icon(
            icon: const Icon(Icons.add_link, size: 16),
            label: const Text('Asignar CFDI'),
            style: FilledButton.styleFrom(
              backgroundColor: GloboColors.primary,
              padding: const EdgeInsets.symmetric(
                  horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
            ),
            onPressed: () => _mostrarDialogo(context, ref),
          ),
        ]),
      ),
    );
  }

  void _mostrarDialogo(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.article_outlined),
          const SizedBox(width: GloboSpacing.sm),
          Text('Asignar UUID CFDI — ${factura.numeroFactura}'),
        ]),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Ingrese el UUID del Complemento Carta Porte 3.0 generado en su PAC.',
              style: GloboTypography.bodyMedium
                  .copyWith(color: GloboColors.textSecondary),
            ),
            const SizedBox(height: GloboSpacing.md),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'UUID CFDI (formato xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)',
                border: OutlineInputBorder(),
                hintText: 'e.g. 6128396f-c09b-4ec6-8699-43c5f7e3b230',
              ),
              autofocus: true,
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final uuid = ctrl.text.trim();
              if (uuid.isEmpty) return;
              Navigator.of(ctx).pop();
              final fn = ref.read(registrarCartaPorteProvider);
              final result = await fn(factura.id, uuid);
              if (!context.mounted) return;
              result.fold(
                (failure) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $failure')),
                ),
                (_) => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('UUID CFDI registrado correctamente.'),
                    backgroundColor: GloboColors.successAccent,
                  ),
                ),
              );
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }
}

// ── Shared KPI Card ───────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(GloboSpacing.md),
        decoration: BoxDecoration(
          color: GloboColors.surface,
          borderRadius: GloboRadius.cardRadius,
          border: Border.all(color: GloboColors.divider),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: GloboRadius.buttonRadius,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: GloboSpacing.md),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GloboTypography.labelSmall),
            Text(value,
                style: GloboTypography.titleLarge.copyWith(color: color)),
          ]),
        ]),
      ),
    );
  }
}

// ── Skeleton de carga ─────────────────────────────────────────────────────────

class _ShimmerTabContent extends StatelessWidget {
  const _ShimmerTabContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.lg),
      child: Shimmer.fromColors(
        baseColor: isDark ? GloboColors.darkBackgroundTertiary : GloboColors.divider,
        highlightColor: isDark ? GloboColors.darkSurfaceElevated : GloboColors.backgroundSecondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: GloboSpacing.md),
              child: Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: GloboRadius.buttonRadius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
