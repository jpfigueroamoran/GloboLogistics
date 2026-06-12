import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    final tipo       = data['tipo'] as String? ?? '';
    final esSOS      = tipo == TipoAlerta.sos.name;
    final evidencias = (data['evidencias'] as List<dynamic>? ?? []);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: esSOS ? GloboColors.sosPrimary : GloboColors.warning,
            width: 4,
          ),
        ),
        color: esSOS ? GloboColors.errorLight : GloboColors.warningLight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
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
            trailing: esSOS ? _SosPulse() : const Icon(Icons.chevron_right, size: 16),
          ),
          // ── Botón de evidencias (solo SOS con media adjunta) ──────────────
          if (esSOS && evidencias.isNotEmpty)
            InkWell(
              onTap: () =>
                  _verEvidencias(context, data['id'] as String? ?? ''),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
                child: Row(children: [
                  const Icon(Icons.perm_media_outlined,
                      size: 14, color: GloboColors.sosPrimary),
                  const SizedBox(width: 6),
                  Text(
                    '${evidencias.length} evidencia${evidencias.length > 1 ? 's' : ''} adjunta${evidencias.length > 1 ? 's' : ''}',
                    style: GloboTypography.caption
                        .copyWith(color: GloboColors.sosPrimary),
                  ),
                  const Spacer(),
                  const Icon(Icons.open_in_new,
                      size: 13, color: GloboColors.sosPrimary),
                ]),
              ),
            ),
          // ── Captura remota (solo SOS activo) ──────────────────────────────
          if (esSOS)
            _CapturaRemotaSection(
              alertaId:      data['id'] as String? ?? '',
              capturaRemota: data['captura_remota'] as Map<String, dynamic>?,
            ),
        ],
      ),
    );
  }

  void _verEvidencias(BuildContext context, String alertaId) {
    if (alertaId.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EvidenciasSheet(alertaId: alertaId),
    );
  }

  String _tipoLabel(String tipo) => switch (tipo) {
        'geocerca'            => 'Violación de Geocerca',
        'varianzaCombustible' => 'Varianza Combustible',
        'detencionProlongada' => 'Detención Prolongada',
        'ticketAnomalo'       => 'Ticket de Combustible Anómalo',
        'polizaPorVencer'     => 'Póliza por Vencer',
        'stockMinimo'         => 'Stock Mínimo en Inventario',
        _                     => tipo,
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

// ── Sección de captura remota (supervisor activa mic/cámara en dispositivo) ───

class _CapturaRemotaSection extends StatefulWidget {
  final String alertaId;
  final Map<String, dynamic>? capturaRemota;
  const _CapturaRemotaSection({required this.alertaId, this.capturaRemota});

  @override
  State<_CapturaRemotaSection> createState() => _CapturaRemotaSectionState();
}

class _CapturaRemotaSectionState extends State<_CapturaRemotaSection> {
  bool _cargando = false;

  Future<void> _activar(String tipo) async {
    if (_cargando || widget.alertaId.isEmpty) return;
    setState(() => _cargando = true);
    try {
      await sl<FirestoreDatasource>()
          .solicitarCapturaRemota(widget.alertaId, tipo);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.capturaRemota?['estado'] as String?;
    final tipo   = widget.capturaRemota?['tipo']   as String?;

    final pendiente  = estado == 'pendiente';
    final completada = estado == 'completada';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(8),
        borderRadius: GloboRadius.buttonRadius,
        border: Border.all(color: GloboColors.sosPrimary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.sensors, size: 13, color: GloboColors.sosPrimary),
            const SizedBox(width: 5),
            Text(
              'CAPTURA REMOTA',
              style: GloboTypography.labelSmall.copyWith(
                color: GloboColors.sosPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (pendiente)
            Row(children: [
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: GloboColors.sosPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                'Capturando ${tipo == 'camara' ? 'foto' : 'audio'} en dispositivo...',
                style: GloboTypography.caption
                    .copyWith(color: GloboColors.sosPrimary),
              ),
            ])
          else if (completada)
            Row(children: [
              const Icon(Icons.check_circle_outline,
                  size: 15, color: GloboColors.success),
              const SizedBox(width: 6),
              Text(
                'Captura completada — ver evidencias',
                style: GloboTypography.caption
                    .copyWith(color: GloboColors.success),
              ),
            ])
          else
            Row(children: [
              Expanded(
                child: _CapturaBtn(
                  icon: Icons.mic_outlined,
                  label: 'Micrófono',
                  enabled: !_cargando,
                  onPressed: () => _activar('audio'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CapturaBtn(
                  icon: Icons.camera_alt_outlined,
                  label: 'Cámara',
                  enabled: !_cargando,
                  onPressed: () => _activar('camara'),
                ),
              ),
            ]),
        ],
      ),
    );
  }
}

class _CapturaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  const _CapturaBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: GloboColors.sosPrimary.withAlpha(80)),
            borderRadius: GloboRadius.buttonRadius,
            color: GloboColors.sosPrimary.withAlpha(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: GloboColors.sosPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: GloboTypography.labelSmall
                    .copyWith(color: GloboColors.sosPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hoja de evidencias para supervisores ─────────────────────────────────────
// Las evidencias viven en la subcolección `evidencias` de la alerta como
// base64 (plan gratuito sin Firebase Storage).

class _EvidenciasSheet extends StatefulWidget {
  final String alertaId;
  const _EvidenciasSheet({required this.alertaId});

  @override
  State<_EvidenciasSheet> createState() => _EvidenciasSheetState();
}

class _EvidenciasSheetState extends State<_EvidenciasSheet> {
  AudioPlayer? _player;
  String? _playingId;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String id, String datosB64) async {
    if (_playingId == id) {
      await _player?.stop();
      setState(() => _playingId = null);
      return;
    }
    await _player?.stop();
    _player?.dispose();
    final p = AudioPlayer();
    _player = p;
    p.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
    setState(() => _playingId = id);
    // En web BytesSource no está soportado — se usa un data URI
    if (kIsWeb) {
      await p.play(UrlSource('data:audio/mp4;base64,$datosB64'));
    } else {
      await p.play(BytesSource(base64Decode(datosB64)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: sl<FirestoreDatasource>().watchEvidenciasSOS(widget.alertaId),
        builder: (context, snap) {
          final evidencias = snap.data ?? [];
          return Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  const Icon(Icons.security,
                      size: 18, color: GloboColors.sosPrimary),
                  const SizedBox(width: 8),
                  Text('Evidencias del Incidente',
                      style: GloboTypography.titleMedium),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: GloboColors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: GloboColors.sosPrimary.withAlpha(60)),
                    ),
                    child: Text('${evidencias.length}',
                        style: GloboTypography.labelSmall
                            .copyWith(color: GloboColors.sosPrimary)),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: !snap.hasData
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : GridView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: evidencias.length,
                        itemBuilder: (_, i) {
                          final ev    = evidencias[i];
                          final id    = ev['id']    as String? ?? '$i';
                          final tipo  = ev['tipo']  as String? ?? '';
                          final datos = ev['datos'] as String? ?? '';

                          if (tipo == 'foto') {
                            return _FotoEvidencia(datosB64: datos);
                          }

                          // Audio
                          final isPlaying = _playingId == id;
                          return GestureDetector(
                            onTap: () => _toggleAudio(id, datos),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isPlaying
                                    ? GloboColors.errorLight
                                    : GloboColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isPlaying
                                      ? GloboColors.sosPrimary
                                      : GloboColors.divider,
                                  width: isPlaying ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isPlaying
                                        ? Icons.stop_circle_outlined
                                        : Icons.play_circle_outline,
                                    size: 42,
                                    color: isPlaying
                                        ? GloboColors.sosPrimary
                                        : GloboColors.textSecondary,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isPlaying ? 'Reproduciendo…' : 'Audio',
                                    style: GloboTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                          );
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

class _FotoEvidencia extends StatelessWidget {
  final String datosB64;
  const _FotoEvidencia({required this.datosB64});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(datosB64);
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      return Container(
        color: GloboColors.surfaceElevated,
        child: const Icon(Icons.broken_image_outlined,
            color: GloboColors.textTertiary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(child: Image.memory(bytes!)),
          ),
        ),
        child: Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}
