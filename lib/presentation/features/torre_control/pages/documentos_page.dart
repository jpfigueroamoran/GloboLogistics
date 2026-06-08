import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/documento_vencimiento.dart';
import '../providers/documentos_provider.dart';
import '../widgets/cargar_documento_dialog.dart';

class DocumentosPage extends ConsumerWidget {
  const DocumentosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentosAsync = ref.watch(documentosProvider);
    final vencidos    = ref.watch(documentosVencidosCountProvider);
    final proximos    = ref.watch(documentosProximosCountProvider);
    final ahora       = DateTime.now();

    if (documentosAsync.isLoading) return const _DocumentosShimmer();

    final docs = documentosAsync.valueOrNull ?? [];

    final vencidosList = docs
        .where((d) => d.semaforo(ahora) == SemaforoDocumento.vencido)
        .toList();
    final proximosList = docs
        .where((d) => d.semaforo(ahora) == SemaforoDocumento.proximoVencer)
        .toList();
    final vigentesList = docs
        .where((d) => d.semaforo(ahora) == SemaforoDocumento.vigente)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            total: docs.length,
            vencidos: vencidos,
            proximos: proximos,
          ),
          const SizedBox(height: GloboSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vencidosList.isNotEmpty) ...[
                  Expanded(
                    child: _Seccion(
                      titulo: 'VENCIDOS',
                      documentos: vencidosList,
                      color: GloboColors.error,
                      ahora: ahora,
                    ),
                  ),
                  const SizedBox(width: GloboSpacing.md),
                ],
                if (proximosList.isNotEmpty) ...[
                  Expanded(
                    child: _Seccion(
                      titulo: 'PRÓXIMOS A VENCER',
                      documentos: proximosList,
                      color: GloboColors.warningAccent,
                      ahora: ahora,
                    ),
                  ),
                  const SizedBox(width: GloboSpacing.md),
                ],
                Expanded(
                  child: _Seccion(
                    titulo: 'VIGENTES',
                    documentos: vigentesList,
                    color: GloboColors.successAccent,
                    ahora: ahora,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Encabezado ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int total;
  final int vencidos;
  final int proximos;

  const _Header({
    required this.total,
    required this.vencidos,
    required this.proximos,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Documentos y Vencimientos',
                  style: GloboTypography.headlineMedium),
              Text(
                '$total documentos registrados',
                style: GloboTypography.bodyMedium,
              ),
            ],
          ),
        ),
        if (vencidos > 0)
          _StatChip(
            label: '$vencidos Vencidos',
            color: GloboColors.error,
            icon: Icons.cancel_outlined,
          ),
        if (vencidos > 0 && proximos > 0)
          const SizedBox(width: GloboSpacing.sm),
        if (proximos > 0)
          _StatChip(
            label: '$proximos Próximos',
            color: GloboColors.warningAccent,
            icon: Icons.schedule_outlined,
          ),
        const SizedBox(width: GloboSpacing.md),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file_outlined, size: 16),
          label: const Text('Cargar Documento'),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const CargarDocumentoDialog(),
            );
          },
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.sm, vertical: GloboSpacing.xs),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: GloboRadius.buttonRadius,
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GloboTypography.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Sección de documentos por estado ─────────────────────────────────────────

class _Seccion extends StatelessWidget {
  final String titulo;
  final List<DocumentoVencimiento> documentos;
  final Color color;
  final DateTime ahora;

  const _Seccion({
    required this.titulo,
    required this.documentos,
    required this.color,
    required this.ahora,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(color: color.withAlpha(60), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(GloboRadius.md),
                topRight: Radius.circular(GloboRadius.md),
              ),
            ),
            child: Row(
              children: [
                Text(
                  titulo,
                  style: GloboTypography.labelSmall
                      .copyWith(color: color, letterSpacing: 1.5),
                ),
                const Spacer(),
                Container(
                  width: 22,
                  height: 22,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '${documentos.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: documentos.isEmpty
                ? Center(
                    child: Text('Sin documentos',
                        style: GloboTypography.caption))
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: documentos.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0),
                    itemBuilder: (_, i) => _DocumentoTile(
                      doc: documentos[i],
                      color: color,
                      ahora: ahora,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DocumentoTile extends StatelessWidget {
  final DocumentoVencimiento doc;
  final Color color;
  final DateTime ahora;

  const _DocumentoTile({
    required this.doc,
    required this.color,
    required this.ahora,
  });

  @override
  Widget build(BuildContext context) {
    final dias = doc.diasRestantes(ahora);
    final diasLabel = dias < 0
        ? 'Venció hace ${(-dias)} días'
        : dias == 0
            ? 'Vence hoy'
            : 'Vence en $dias días';

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: GloboRadius.cardRadius,
        ),
        child: Icon(
          doc.esDocumentoDeUnidad
              ? Icons.local_shipping_outlined
              : Icons.person_outline,
          size: 18,
          color: color,
        ),
      ),
      title: Text(doc.nombreEntidad, style: GloboTypography.titleMedium),
      subtitle: Text(doc.tipoLabel, style: GloboTypography.caption),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${doc.fechaVencimiento.day.toString().padLeft(2, '0')}/'
            '${doc.fechaVencimiento.month.toString().padLeft(2, '0')}/'
            '${doc.fechaVencimiento.year}',
            style: GloboTypography.monoData.copyWith(fontSize: 12),
          ),
          Text(
            diasLabel,
            style: GloboTypography.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton de carga ─────────────────────────────────────────────────────────

class _DocumentosShimmer extends StatelessWidget {
  const _DocumentosShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: GloboColors.backgroundTertiary,
      highlightColor: GloboColors.backgroundSecondary,
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fake header
            Container(
              height: 22,
              width: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: GloboRadius.buttonRadius,
              ),
            ),
            const SizedBox(height: GloboSpacing.sm),
            Container(
              height: 14,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: GloboRadius.buttonRadius,
              ),
            ),
            const SizedBox(height: GloboSpacing.md),
            // Fake 3-column sections
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(3, (col) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: col < 2 ? GloboSpacing.md : 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: GloboRadius.cardRadius,
                      ),
                      child: Column(
                        children: [
                          // Column header
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft:  Radius.circular(GloboRadius.md),
                                topRight: Radius.circular(GloboRadius.md),
                              ),
                            ),
                          ),
                          ...List.generate(4, (_) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: GloboSpacing.md,
                              vertical: GloboSpacing.sm,
                            ),
                            child: Row(children: [
                              Container(
                                  width: 36, height: 36,
                                  color: Colors.white),
                              const SizedBox(width: GloboSpacing.sm),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(height: 13, color: Colors.white),
                                  const SizedBox(height: 5),
                                  Container(height: 10, width: 90,
                                      color: Colors.white),
                                ],
                              )),
                            ]),
                          )),
                        ],
                      ),
                    ),
                  ),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
