import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

/// Overlay de pantalla completa que aparece automáticamente en el dispositivo
/// del operador cuando Torre de Control activa una captura remota de evidencia.
class CapturaRemotaOverlay extends ConsumerStatefulWidget {
  final String alertaId;
  final String tipo;       // 'audio' | 'camara'
  final String operadorId;

  const CapturaRemotaOverlay({
    super.key,
    required this.alertaId,
    required this.tipo,
    required this.operadorId,
  });

  @override
  ConsumerState<CapturaRemotaOverlay> createState() =>
      _CapturaRemotaOverlayState();
}

class _CapturaRemotaOverlayState extends ConsumerState<CapturaRemotaOverlay> {
  final _recorder = AudioRecorder();

  // Audio state
  bool _grabando   = false;
  int  _segsGrabando = 0;

  // Camera state
  int  _countdown  = 4; // segundos antes de abrir cámara

  // Shared
  Timer? _timer;
  bool  _subiendo   = false;
  bool  _completado = false;
  bool  _error      = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Dispatcher ────────────────────────────────────────────────────────────

  void _iniciar() {
    if (widget.tipo == 'audio') {
      _iniciarAudio();
    } else {
      _iniciarCamara();
    }
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Future<void> _iniciarAudio() async {
    final tienePermiso = await _recorder.hasPermission();
    if (!tienePermiso) {
      if (mounted) setState(() => _error = true);
      _cerrarEn(2);
      return;
    }

    final dir  = await getTemporaryDirectory();
    final path =
        '${dir.path}/remoto_${DateTime.now().millisecondsSinceEpoch}.m4a';
    // 48 kbps AAC mono: 60s ≈ 360 KB — cabe en un doc de Firestore como base64
    await _recorder.start(
      const RecordConfig(bitRate: 48000, numChannels: 1),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _grabando     = true;
      _segsGrabando = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _segsGrabando++);
      if (_segsGrabando >= 60) _detenerAudio();
    });
  }

  Future<void> _detenerAudio() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() { _grabando = false; _subiendo = true; });
    if (path == null) { _cerrarEn(2); return; }
    await _subirArchivo(await File(path).readAsBytes(), 'audio');
  }

  // ── Cámara ────────────────────────────────────────────────────────────────

  void _iniciarCamara() {
    setState(() => _countdown = 4);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _abrirCamara();
      }
    });
  }

  Future<void> _abrirCamara() async {
    // Compresión agresiva: la foto se guarda en Firestore (límite 1 MiB/doc)
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 55,
      maxWidth: 1280,
    );
    if (!mounted) return;
    if (img == null) {
      // El operador no puede cancelar — se vuelve a abrir la cámara
      _abrirCamara();
      return;
    }
    setState(() => _subiendo = true);
    await _subirArchivo(await img.readAsBytes(), 'foto');
  }

  // ── Guardado en Firestore (plan gratuito, sin Storage) ───────────────────

  static const _maxBytes = 700 * 1024; // margen bajo el límite de 1 MiB/doc

  Future<void> _subirArchivo(Uint8List bytes, String tipo) async {
    try {
      if (bytes.length > _maxBytes) {
        throw Exception('Evidencia demasiado grande');
      }
      final db = sl<FirestoreDatasource>();
      await Future.wait([
        db.agregarEvidenciaSOS(
          alertaId: widget.alertaId,
          tipo:     tipo,
          datosB64: base64Encode(bytes),
        ),
        db.completarCapturaRemota(widget.alertaId),
      ]);

      if (mounted) setState(() { _subiendo = false; _completado = true; });
    } catch (_) {
      if (mounted) setState(() { _subiendo = false; _error = true; });
    } finally {
      _cerrarEn(2);
    }
  }

  void _cerrarEn(int segundos) {
    Future.delayed(Duration(seconds: segundos), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _completado || _error,
      child: Material(
        color: GloboColors.sosPrimary,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(GloboSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Encabezado ──────────────────────────────────────────────
                const Icon(Icons.security, size: 48, color: Colors.white),
                const SizedBox(height: GloboSpacing.md),
                Text(
                  'CAPTURA DE EMERGENCIA',
                  style: GloboTypography.headlineMedium
                      .copyWith(color: Colors.white, letterSpacing: 1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: GloboSpacing.xs),
                Text(
                  'Activada por Torre de Control',
                  style: GloboTypography.bodyMedium
                      .copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: GloboSpacing.xl),
                const Divider(color: Colors.white24),
                const SizedBox(height: GloboSpacing.xl),

                // ── Contenido según estado ──────────────────────────────────
                if (_completado)
                  _EstadoFinal(exito: true)
                else if (_error)
                  _EstadoFinal(exito: false)
                else if (_subiendo)
                  _SubiendoView()
                else if (widget.tipo == 'audio')
                  _AudioView(
                    grabando:      _grabando,
                    segsGrabando: _segsGrabando,
                  )
                else
                  _CamaraCountdown(countdown: _countdown),

                const SizedBox(height: GloboSpacing.xl),
                const Divider(color: Colors.white24),
                const SizedBox(height: GloboSpacing.md),

                Text(
                  'Las evidencias se envían automáticamente\na Torre de Control para verificación.',
                  style: GloboTypography.caption
                      .copyWith(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets del overlay ───────────────────────────────────────────────────

class _AudioView extends StatefulWidget {
  final bool grabando;
  final int  segsGrabando;
  const _AudioView({required this.grabando, required this.segsGrabando});

  @override
  State<_AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<_AudioView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ScaleTransition(
        scale: widget.grabando
            ? Tween<double>(begin: 0.88, end: 1.12).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut))
            : kAlwaysCompleteAnimation,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(30),
            border: Border.all(color: Colors.white54, width: 2),
          ),
          child: const Icon(Icons.mic, size: 48, color: Colors.white),
        ),
      ),
      const SizedBox(height: GloboSpacing.md),
      Text(
        widget.grabando ? 'Grabando audio...' : 'Iniciando micrófono...',
        style: GloboTypography.titleMedium.copyWith(color: Colors.white),
      ),
      if (widget.grabando) ...[
        const SizedBox(height: GloboSpacing.sm),
        SizedBox(
          width: 240,
          child: LinearProgressIndicator(
            value: widget.segsGrabando / 60,
            backgroundColor: Colors.white24,
            color: Colors.white,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${60 - widget.segsGrabando}s restantes',
          style:
              GloboTypography.caption.copyWith(color: Colors.white70),
        ),
      ],
    ]);
  }
}

class _CamaraCountdown extends StatelessWidget {
  final int countdown;
  const _CamaraCountdown({required this.countdown});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(
        countdown > 0
            ? Icons.camera_alt_outlined
            : Icons.camera_alt,
        size: 72,
        color: Colors.white,
      ),
      const SizedBox(height: GloboSpacing.md),
      Text(
        countdown > 0
            ? 'Abriendo cámara en $countdown...'
            : 'Capturando evidencia...',
        style: GloboTypography.headlineMedium.copyWith(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

class _SubiendoView extends StatelessWidget {
  const _SubiendoView();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
      const SizedBox(height: GloboSpacing.md),
      Text(
        'Enviando a Torre de Control...',
        style: GloboTypography.titleMedium.copyWith(color: Colors.white),
      ),
    ]);
  }
}

class _EstadoFinal extends StatelessWidget {
  final bool exito;
  const _EstadoFinal({required this.exito});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(
        exito ? Icons.check_circle_outline : Icons.error_outline,
        size: 72,
        color: exito ? Colors.greenAccent : Colors.redAccent,
      ),
      const SizedBox(height: GloboSpacing.md),
      Text(
        exito ? 'Evidencia enviada' : 'Error al enviar',
        style: GloboTypography.headlineMedium.copyWith(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    ]);
  }
}
