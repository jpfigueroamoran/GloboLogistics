import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/activo_fijo.dart';
import '../../../../domain/entities/cuenta_por_cobrar.dart';
import '../../../../domain/entities/documento_vencimiento.dart';
import '../../../../domain/entities/factura_cliente.dart';
import '../../../../domain/entities/poliza_seguro.dart';
import '../providers/activo_fijo_provider.dart';
import '../providers/factura_cliente_provider.dart';
import '../providers/poliza_seguro_provider.dart';

class FinanzasPage extends ConsumerStatefulWidget {
  const FinanzasPage({super.key});

  @override
  ConsumerState<FinanzasPage> createState() => _FinanzasPageState();
}

class _FinanzasPageState extends ConsumerState<FinanzasPage>
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
        _FinanzasTabBar(controller: _tabController),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _ActivosFijosTab(),
              _PolizasTab(),
              _CxCTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── TabBar ────────────────────────────────────────────────────────────────────

class _FinanzasTabBar extends StatelessWidget {
  final TabController controller;
  const _FinanzasTabBar({required this.controller});

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
          Tab(
            icon: Icon(Icons.directions_car_outlined, size: 18),
            text: 'Activos Fijos',
          ),
          Tab(
            icon: Icon(Icons.shield_outlined, size: 18),
            text: 'Pólizas de Seguro',
          ),
          Tab(
            icon: Icon(Icons.receipt_long_outlined, size: 18),
            text: 'Cuentas x Cobrar',
          ),
        ],
      ),
    );
  }
}

// ── TAB 1: Activos Fijos ──────────────────────────────────────────────────────

class _ActivosFijosTab extends ConsumerWidget {
  const _ActivosFijosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activosAsync = ref.watch(activosFijosProvider);
    final valorFlota = ref.watch(valorFlotaProvider);
    final deprMensual = ref.watch(depreciacionMensualTotalProvider);
    final enAlerta = ref.watch(activosEnAlertaCountProvider);
    final ahora = DateTime.now();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return activosAsync.when(
      loading: () => const _ShimmerTabContent(),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (activos) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivosKpiRow(
            valorFlota: valorFlota,
            deprMensual: deprMensual,
            enAlerta: enAlerta,
            total: activos.length,
            fmt: fmt,
          ),
          const Divider(height: 0),
          _ActivosTableHeader(),
          const Divider(height: 0),
          Expanded(
            child: activos.isEmpty
                ? const Center(child: Text('Sin activos fijos registrados'))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: activos.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) =>
                        _ActivoRow(activo: activos[i], ahora: ahora, fmt: fmt),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActivosKpiRow extends StatelessWidget {
  final double valorFlota;
  final double deprMensual;
  final int enAlerta;
  final int total;
  final NumberFormat fmt;

  const _ActivosKpiRow({
    required this.valorFlota,
    required this.deprMensual,
    required this.enAlerta,
    required this.total,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
      child: Row(
        children: [
          _KpiCard(
            label: 'Valor de Flota en Libros',
            value: fmt.format(valorFlota),
            icon: Icons.account_balance_outlined,
            color: GloboColors.accentBright,
          ),
          const SizedBox(width: GloboSpacing.md),
          _KpiCard(
            label: 'Depreciación Mensual Flota',
            value: fmt.format(deprMensual),
            icon: Icons.trending_down_outlined,
            color: GloboColors.warningAccent,
          ),
          const SizedBox(width: GloboSpacing.md),
          _KpiCard(
            label: 'Activos >80% Depreciados',
            value: '$enAlerta de $total',
            icon: Icons.warning_amber_outlined,
            color:
                enAlerta > 0 ? GloboColors.error : GloboColors.successAccent,
          ),
        ],
      ),
    );
  }
}

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
          color: color.withAlpha(12),
          borderRadius: GloboRadius.cardRadius,
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: GloboRadius.buttonRadius,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: GloboSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GloboTypography.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GloboTypography.titleLarge
                        .copyWith(color: color, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivosTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      child: const Row(
        children: [
          Expanded(
              flex: 3,
              child: Text('Unidad / Activo',
                  style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child: Text('Costo Adquisición',
                  style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child:
                  Text('Valor en Libros', style: GloboTypography.labelSmall)),
          Expanded(
              flex: 3,
              child: Text('Depreciación Acumulada',
                  style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child:
                  Text('Depr. Mensual', style: GloboTypography.labelSmall)),
          SizedBox(width: GloboSpacing.lg),
        ],
      ),
    );
  }
}

class _ActivoRow extends StatelessWidget {
  final ActivoFijo activo;
  final DateTime ahora;
  final NumberFormat fmt;

  const _ActivoRow({
    required this.activo,
    required this.ahora,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final pct = activo.porcentajeDepreciado(ahora);
    final vl = activo.valorLibros(ahora);
    final isAlerta = pct >= 0.8;
    final barColor = pct >= 0.8
        ? GloboColors.error
        : pct >= 0.5
            ? GloboColors.warningAccent
            : GloboColors.successAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      child: Row(
        children: [
          // Unidad / Activo
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activo.descripcion, style: GloboTypography.titleMedium),
                Text(activo.unidadId, style: GloboTypography.caption),
              ],
            ),
          ),
          // Costo adquisición
          Expanded(
            flex: 2,
            child: Text(fmt.format(activo.costoAdquisicion),
                style: GloboTypography.monoData),
          ),
          // Valor en libros
          Expanded(
            flex: 2,
            child: Text(
              fmt.format(vl),
              style: GloboTypography.monoData.copyWith(
                color: isAlerta ? GloboColors.error : GloboColors.textPrimary,
                fontWeight: isAlerta ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          // Barra depreciación
          Expanded(
            flex: 3,
            child: Column(
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
                  '${(pct * 100).toStringAsFixed(1)}% depreciado',
                  style: GloboTypography.caption.copyWith(color: barColor),
                ),
              ],
            ),
          ),
          // Depreciación mensual
          Expanded(
            flex: 2,
            child: Text(fmt.format(activo.depreciacionMensual),
                style: GloboTypography.monoData),
          ),
          // Icono alerta
          SizedBox(
            width: GloboSpacing.lg,
            child: isAlerta
                ? const Tooltip(
                    message: 'Activo con >80% de vida útil consumida',
                    child: Icon(Icons.warning_amber_rounded,
                        color: GloboColors.error, size: 18),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ── TAB 2: Pólizas de Seguro ──────────────────────────────────────────────────

class _PolizasTab extends ConsumerWidget {
  const _PolizasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polizasAsync = ref.watch(polizasProvider);
    final primaTotal = ref.watch(primaTotalMensualProvider);
    final enAlerta = ref.watch(polizasAlertaCountProvider);
    final ahora = DateTime.now();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return polizasAsync.when(
      loading: () => const _ShimmerTabContent(),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (polizas) => Column(
        children: [
          _PolizasKpiRow(
            primaTotal: primaTotal,
            enAlerta: enAlerta,
            total: polizas.length,
            fmt: fmt,
          ),
          const Divider(height: 0),
          Expanded(
            child: polizas.isEmpty
                ? const Center(child: Text('Sin pólizas registradas'))
                : ListView.separated(
                    padding: const EdgeInsets.all(GloboSpacing.md),
                    itemCount: polizas.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: GloboSpacing.sm),
                    itemBuilder: (_, i) =>
                        _PolizaCard(poliza: polizas[i], ahora: ahora, fmt: fmt),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PolizasKpiRow extends StatelessWidget {
  final double primaTotal;
  final int enAlerta;
  final int total;
  final NumberFormat fmt;

  const _PolizasKpiRow({
    required this.primaTotal,
    required this.enAlerta,
    required this.total,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
      child: Row(
        children: [
          _KpiCard(
            label: 'Prima Total Mensual',
            value: fmt.format(primaTotal),
            icon: Icons.attach_money_outlined,
            color: GloboColors.accentBright,
          ),
          const SizedBox(width: GloboSpacing.md),
          _KpiCard(
            label: 'Vencidas / Próximas a Vencer',
            value: '$enAlerta de $total',
            icon: Icons.schedule_outlined,
            color:
                enAlerta > 0 ? GloboColors.error : GloboColors.successAccent,
          ),
          const SizedBox(width: GloboSpacing.md),
          _KpiCard(
            label: 'Prima Anual Proyectada',
            value: fmt.format(primaTotal * 12),
            icon: Icons.calendar_today_outlined,
            color: GloboColors.steelGray,
          ),
        ],
      ),
    );
  }
}

class _PolizaCard extends StatelessWidget {
  final PolizaSeguro poliza;
  final DateTime ahora;
  final NumberFormat fmt;

  const _PolizaCard({
    required this.poliza,
    required this.ahora,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final semaforo = poliza.semaforo(ahora);
    final dias = poliza.diasRestantes(ahora);

    final (semaforoColor, semaforoLabel) = switch (semaforo) {
      SemaforoDocumento.vigente => (GloboColors.successAccent, 'Vigente'),
      SemaforoDocumento.proximoVencer =>
        (GloboColors.warningAccent, 'Vence en $dias días'),
      SemaforoDocumento.vencido =>
        (GloboColors.error, 'Venció hace ${-dias} días'),
    };

    final fmtFecha = DateFormat('dd/MM/yyyy');

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(
          color: semaforoColor.withAlpha(80),
          width: semaforo != SemaforoDocumento.vigente ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Row(
          children: [
            // Semáforo
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: semaforoColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: GloboSpacing.md),
            // Tipo + unidad
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poliza.tipoLabel,
                      style: GloboTypography.titleMedium),
                  Text(poliza.unidadLabel,
                      style: GloboTypography.caption),
                ],
              ),
            ),
            // Aseguradora
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aseguradora',
                      style: GloboTypography.labelSmall),
                  Text(poliza.aseguradora,
                      style: GloboTypography.bodyMedium),
                ],
              ),
            ),
            // No. póliza
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No. Póliza',
                      style: GloboTypography.labelSmall),
                  Text(poliza.numeroPoliza,
                      style: GloboTypography.monoData
                          .copyWith(fontSize: 12)),
                ],
              ),
            ),
            // Prima mensual
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prima Mensual',
                      style: GloboTypography.labelSmall),
                  Text(fmt.format(poliza.primaMensual),
                      style: GloboTypography.monoData),
                ],
              ),
            ),
            // Vigencia + estado
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Vigencia',
                      style: GloboTypography.labelSmall),
                  Text(
                    fmtFecha.format(poliza.vigenciaFin),
                    style: GloboTypography.monoData.copyWith(fontSize: 12),
                  ),
                  Text(
                    semaforoLabel,
                    style: GloboTypography.caption
                        .copyWith(color: semaforoColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TAB 3: Cuentas por Cobrar ─────────────────────────────────────────────────

class _CxCTab extends ConsumerWidget {
  const _CxCTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facturasAsync = ref.watch(facturasProvider);
    final cxc = ref.watch(cxcProvider);
    final totalPendiente = ref.watch(cxcTotalPendienteProvider);
    final vencidas = ref.watch(facturasVencidasCountProvider);
    final cobradoMes = ref.watch(ingresosCobradosMesProvider);
    final ahora = DateTime.now();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return facturasAsync.when(
      loading: () => const _ShimmerTabContent(),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (_) => Column(
        children: [
          // KPI strip
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
            child: Row(
              children: [
                _KpiCard(
                  label: 'Total por Cobrar',
                  value: fmt.format(totalPendiente),
                  icon: Icons.account_balance_wallet_outlined,
                  color: totalPendiente > 0
                      ? GloboColors.warningAccent
                      : GloboColors.successAccent,
                ),
                const SizedBox(width: GloboSpacing.md),
                _KpiCard(
                  label: 'Facturas Vencidas',
                  value: '$vencidas facturas',
                  icon: Icons.assignment_late_outlined,
                  color:
                      vencidas > 0 ? GloboColors.error : GloboColors.successAccent,
                ),
                const SizedBox(width: GloboSpacing.md),
                _KpiCard(
                  label: 'Cobrado Este Mes',
                  value: fmt.format(cobradoMes),
                  icon: Icons.check_circle_outline,
                  color: GloboColors.successAccent,
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          // Leyenda de aging
          _AgingLegend(),
          const Divider(height: 0),
          // Header de tabla
          _AgingTableHeader(),
          const Divider(height: 0),
          // Filas por cliente
          Expanded(
            child: cxc.isEmpty
                ? const Center(
                    child: Text('Sin cuentas por cobrar pendientes'))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: cxc.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) => _AgingRow(
                      cxc: cxc[i],
                      ahora: ahora,
                      fmt: fmt,
                    ),
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
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.lg, vertical: GloboSpacing.sm),
      child: Row(
        children: [
          Text('Aging: ', style: GloboTypography.labelSmall),
          const SizedBox(width: GloboSpacing.sm),
          _LegendChip('Corriente', GloboColors.successAccent),
          const SizedBox(width: GloboSpacing.sm),
          _LegendChip('1–30 días', GloboColors.warningAccent),
          const SizedBox(width: GloboSpacing.sm),
          _LegendChip('31–60 días', const Color(0xFFE65100)),
          const SizedBox(width: GloboSpacing.sm),
          _LegendChip('61–90 días', GloboColors.error),
          const SizedBox(width: GloboSpacing.sm),
          _LegendChip('+90 días', const Color(0xFF7B0000)),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GloboTypography.caption.copyWith(color: color)),
      ],
    );
  }
}

class _AgingTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      child: const Row(
        children: [
          Expanded(
              flex: 3,
              child: Text('Cliente', style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child: Text('Corriente', style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child: Text('1–30 días', style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child: Text('31–60 días', style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child: Text('61–90 días', style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child: Text('+90 días', style: GloboTypography.labelSmall)),
          Expanded(
              flex: 2,
              child: Text('Total', style: GloboTypography.labelSmall)),
          SizedBox(width: GloboSpacing.lg),
        ],
      ),
    );
  }
}

class _AgingRow extends StatelessWidget {
  final CuentaPorCobrar cxc;
  final DateTime ahora;
  final NumberFormat fmt;

  const _AgingRow({
    required this.cxc,
    required this.ahora,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final corriente = cxc.montoEnBucket(BucketAging.corriente, ahora);
    final d30 = cxc.montoEnBucket(BucketAging.vencido30, ahora);
    final d60 = cxc.montoEnBucket(BucketAging.vencido60, ahora);
    final d90 = cxc.montoEnBucket(BucketAging.vencido90, ahora);
    final d90mas = cxc.montoEnBucket(BucketAging.vencido90mas, ahora);
    final nivel = cxc.nivelRiesgo(ahora);

    final (rowBg, iconColor) = switch (nivel) {
      NivelRiesgo.ok => (Colors.transparent, GloboColors.successAccent),
      NivelRiesgo.atencion =>
        (GloboColors.warningAccent.withAlpha(12), GloboColors.warningAccent),
      NivelRiesgo.critico =>
        (GloboColors.error.withAlpha(10), GloboColors.error),
    };

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      child: Row(
        children: [
          // Cliente
          Expanded(
            flex: 3,
            child: Text(cxc.clienteNombre,
                style: GloboTypography.titleMedium),
          ),
          // Corriente
          Expanded(
            flex: 2,
            child: _AgingCell(monto: corriente, color: GloboColors.successAccent, fmt: fmt),
          ),
          // 1-30 días
          Expanded(
            flex: 2,
            child: _AgingCell(monto: d30, color: GloboColors.warningAccent, fmt: fmt),
          ),
          // 31-60 días
          Expanded(
            flex: 2,
            child: _AgingCell(monto: d60, color: const Color(0xFFE65100), fmt: fmt),
          ),
          // 61-90 días
          Expanded(
            flex: 2,
            child: _AgingCell(monto: d90, color: GloboColors.error, fmt: fmt),
          ),
          // +90 días
          Expanded(
            flex: 2,
            child: _AgingCell(monto: d90mas, color: const Color(0xFF7B0000), fmt: fmt),
          ),
          // Total
          Expanded(
            flex: 2,
            child: Text(
              fmt.format(cxc.montoPendienteTotal),
              style: GloboTypography.monoData
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          // Icono nivel
          SizedBox(
            width: GloboSpacing.lg,
            child: nivel != NivelRiesgo.ok
                ? Tooltip(
                    message: nivel == NivelRiesgo.critico
                        ? 'Cartera vencida crítica (>30 días)'
                        : 'Factura próxima a vencer',
                    child: Icon(Icons.warning_amber_rounded,
                        color: iconColor, size: 18),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _AgingCell extends StatelessWidget {
  final double monto;
  final Color color;
  final NumberFormat fmt;

  const _AgingCell({
    required this.monto,
    required this.color,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (monto <= 0) {
      return Text('—',
          style: GloboTypography.caption
              .copyWith(color: GloboColors.textTertiary));
    }
    return Text(
      fmt.format(monto),
      style: GloboTypography.monoData.copyWith(color: color, fontSize: 12),
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
