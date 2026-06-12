import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';
import '../providers/sos_provider.dart';

class SosPage extends ConsumerStatefulWidget {
  final String operadorId;
  final String unidadId;
  final String viajeId;

  const SosPage({
    super.key,
    required this.operadorId,
    required this.unidadId,
    required this.viajeId,
  });

  @override
  ConsumerState<SosPage> createState() => _SosPageState();
}

class _SosPageState extends ConsumerState<SosPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);

    return Scaffold(
      backgroundColor: GloboColors.sosPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(GloboSpacing.md),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white),
                    onPressed: sosState.isActive
                        ? null
                        : () => Navigator.pop(context),
                  ),
                  Text(
                    sosState.isActive
                        ? 'PROTOCOLO SOS ACTIVO'
                        : 'ACTIVAR PROTOCOLO SOS',
                    style: GloboTypography.headlineMedium
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Botón principal SOS — long-press para activar (evita falsas
            // alarmas por toques accidentales); tap cancela con confirmación
            ScaleTransition(
              scale: sosState.isActive ? _pulseAnimation : kAlwaysCompleteAnimation,
              child: _SosMainButton(
                isActive: sosState.isActive,
                isLoading:
                    sosState.status == SosStatus.activating,
                onTap:       () => _handleTap(sosState),
                onLongPress: () => _handleLongPress(sosState),
              ),
            ),

            const SizedBox(height: GloboSpacing.xl),

            // Status info
            _SosStatusInfo(status: sosState.status),

            // Captura de evidencia (solo con SOS activo y alertaId disponible)
            if (sosState.isActive && sosState.alertaId != null) ...[
              const SizedBox(height: GloboSpacing.lg),
              _EvidenciaSection(alertaId: sosState.alertaId!),
            ] else
              const Spacer(),

            // Info legal
            Padding(
              padding: const EdgeInsets.all(GloboSpacing.lg),
              child: Text(
                sosState.isActive
                    ? 'Enviando posición GPS cada 5 segundos.\nTorre de Control notificada.'
                    : 'Mantén presionado para activar el protocolo SOS.\nSe notificará a Torre de Control inmediatamente.',
                style: GloboTypography.bodyMedium
                    .copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(SosState sosState) {
    if (sosState.status == SosStatus.activating) return;
    if (sosState.isActive) {
      _confirmarCancelacion();
      return;
    }
    // Guía al usuario: la activación requiere mantener presionado
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Mantén presionado el botón para activar el SOS'),
        duration: Duration(seconds: 2),
      ));
  }

  void _handleLongPress(SosState sosState) {
    if (sosState.isActive || sosState.status == SosStatus.activating) return;
    HapticFeedback.heavyImpact();
    ref.read(sosProvider.notifier).activarSOS(
          viajeId: widget.viajeId,
          operadorId: widget.operadorId,
          unidadId: widget.unidadId,
        );
  }

  Future<void> _confirmarCancelacion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar el SOS?'),
        content: const Text(
            'Torre de Control verá la alerta como falsa alarma y se dejará '
            'de transmitir tu posición de emergencia.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir activo'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GloboColors.sosPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar SOS'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(sosProvider.notifier).cancelarSOS();
      Navigator.pop(context);
    }
  }
}

class _SosMainButton extends StatelessWidget {
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SosMainButton({
    required this.isActive,
    required this.isLoading,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white : GloboColors.sosSecondary,
          border: Border.all(
            color: Colors.white,
            width: isActive ? 6 : 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: isActive
                        ? GloboColors.sosPrimary
                        : Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SOS',
                    style: GloboTypography.displayLarge.copyWith(
                      color: isActive
                          ? GloboColors.sosPrimary
                          : Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (isActive)
                    Text(
                      'TOCA PARA CANCELAR',
                      style: GloboTypography.labelSmall.copyWith(
                          color: GloboColors.sosPrimary,
                          fontSize: 9),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SosStatusInfo extends StatelessWidget {
  final SosStatus status;

  const _SosStatusInfo({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      SosStatus.idle => (Icons.info_outline, 'En espera'),
      SosStatus.activating => (Icons.sync, 'Activando...'),
      SosStatus.active =>
        (Icons.location_on, 'GPS transmitiendo'),
      SosStatus.cancelling => (Icons.cancel_outlined, 'Cancelando'),
      SosStatus.error =>
        (Icons.error_outline, 'Error de conexión'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.lg, vertical: GloboSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: GloboRadius.cardRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: GloboSpacing.sm),
          Text(label,
              style: GloboTypography.bodyMedium
                  .copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

// ── Evidencia del incidente ───────────────────────────────────────────────────

class _EvidenciaItem {
  final String tipo; // 'foto' | 'audio'
  String estado = 'subiendo'; // 'subiendo' | 'subida' | 'error'
  _EvidenciaItem({required this.tipo});
}

class _EvidenciaSection extends ConsumerStatefulWidget {
  final String alertaId;
  const _EvidenciaSection({required this.alertaId});

  @override
  ConsumerState<_EvidenciaSection> createState() => _EvidenciaSectionState();
}

class _EvidenciaSectionState extends ConsumerState<_EvidenciaSection> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _uploading   = false;
  int  _segsGrabando = 0;
  Timer? _grabTimer;
  final List<_EvidenciaItem> _items = [];

  @override
  void dispose() {
    _grabTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Foto ──────────────────────────────────────────────────────────────────

  Future<void> _tomarFoto() async {
    // Compresión agresiva: la foto se guarda en Firestore (límite 1 MiB/doc)
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 55,
      maxWidth: 1280,
    );
    if (img == null || !mounted) return;
    await _subir(await img.readAsBytes(), 'foto');
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Future<void> _toggleAudio() async {
    _isRecording ? await _detenerAudio() : await _iniciarAudio();
  }

  Future<void> _iniciarAudio() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se requiere permiso de micrófono')),
        );
      }
      return;
    }
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/sos_${DateTime.now().millisecondsSinceEpoch}.m4a';
    // 48 kbps AAC mono: 60s ≈ 360 KB — cabe en un doc de Firestore como base64
    await _recorder.start(
      const RecordConfig(bitRate: 48000, numChannels: 1),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _isRecording   = true;
      _segsGrabando = 0;
    });
    _grabTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _segsGrabando++);
      if (_segsGrabando >= 60) _detenerAudio();
    });
  }

  Future<void> _detenerAudio() async {
    _grabTimer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording   = false;
      _segsGrabando = 0;
    });
    if (path == null) return;
    await _subir(await File(path).readAsBytes(), 'audio');
  }

  // ── Guardado en Firestore (plan gratuito, sin Storage) ───────────────────

  static const _maxBytes = 700 * 1024; // margen bajo el límite de 1 MiB/doc

  Future<void> _subir(Uint8List bytes, String tipo) async {
    final item = _EvidenciaItem(tipo: tipo);
    setState(() {
      _items.add(item);
      _uploading = true;
    });
    try {
      if (bytes.length > _maxBytes) {
        throw Exception('Evidencia demasiado grande (${bytes.length ~/ 1024} KB)');
      }
      await sl<FirestoreDatasource>().agregarEvidenciaSOS(
        alertaId: widget.alertaId,
        tipo:     tipo,
        datosB64: base64Encode(bytes),
      );
      if (mounted) setState(() => item.estado = 'subida');
    } catch (_) {
      if (mounted) setState(() => item.estado = 'error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(GloboSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: GloboRadius.cardRadius,
          border: Border.all(color: Colors.white.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.videocam_outlined,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'EVIDENCIA DEL INCIDENTE',
                style: GloboTypography.labelSmall.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ]),
            const SizedBox(height: GloboSpacing.sm),
            Row(children: [
              Expanded(
                child: _EvidenciaBtn(
                  icon: Icons.camera_alt_outlined,
                  label: 'Foto',
                  enabled: !_uploading && !_isRecording,
                  onPressed: _tomarFoto,
                ),
              ),
              const SizedBox(width: GloboSpacing.sm),
              Expanded(
                child: _EvidenciaBtn(
                  icon: _isRecording
                      ? Icons.stop_circle_outlined
                      : Icons.mic_outlined,
                  label: _isRecording
                      ? 'Detener (${60 - _segsGrabando}s)'
                      : 'Audio',
                  enabled: !_uploading,
                  accentRed: _isRecording,
                  onPressed: _toggleAudio,
                ),
              ),
            ]),
            if (_isRecording) ...[
              const SizedBox(height: GloboSpacing.xs),
              LinearProgressIndicator(
                value: _segsGrabando / 60,
                backgroundColor: Colors.white24,
                color: Colors.redAccent,
                minHeight: 3,
              ),
            ],
            if (_items.isNotEmpty) ...[
              const SizedBox(height: GloboSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _items
                    .map((it) => _EvidenciaChip(item: it))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvidenciaBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool accentRed;
  final VoidCallback onPressed;

  const _EvidenciaBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.accentRed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentRed ? Colors.red.shade300 : Colors.white;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: color.withAlpha(100)),
            borderRadius: GloboRadius.buttonRadius,
            color: color.withAlpha(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Text(label,
                  style: GloboTypography.labelSmall.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenciaChip extends StatelessWidget {
  final _EvidenciaItem item;
  const _EvidenciaChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final tipoIcon = item.tipo == 'foto'
        ? Icons.image_outlined
        : Icons.audio_file_outlined;
    final (statusIcon, statusColor) = switch (item.estado) {
      'subida' => (Icons.check_circle_outline, Colors.greenAccent),
      'error'  => (Icons.error_outline, Colors.redAccent),
      _        => (Icons.upload_outlined, Colors.white54),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(tipoIcon, size: 13, color: Colors.white70),
        const SizedBox(width: 4),
        if (item.estado == 'subiendo')
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: Colors.white70),
          )
        else
          Icon(statusIcon, size: 13, color: statusColor),
      ]),
    );
  }
}
