import 'package:flutter/material.dart';
import '../../core/constants/theme_constants.dart';
import '../../core/services/sos_audio_service.dart';

/// Overlay de pantalla completa para alertas SOS.
///
/// Cubre toda la pantalla, no se puede cerrar con el botón Atrás y reproduce
/// la alarma de emergencia. Se descarta explícitamente con "Atender" o "Ignorar".
class SosOverlay extends StatefulWidget {
  final String titulo;
  final String cuerpo;
  final String operadorId;
  final String unidadId;
  final VoidCallback? onAtender;

  const SosOverlay({
    super.key,
    required this.titulo,
    required this.cuerpo,
    required this.operadorId,
    required this.unidadId,
    this.onAtender,
  });

  /// Muestra el overlay y activa la alarma de audio.
  /// [context] debe tener un Navigator accesible (usa rootNavigatorKey.currentContext).
  static Future<void> show(
    BuildContext context, {
    required String titulo,
    required String cuerpo,
    required String operadorId,
    required String unidadId,
    VoidCallback? onAtender,
  }) {
    SosAudioService.play();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) => SosOverlay(
        titulo: titulo,
        cuerpo: cuerpo,
        operadorId: operadorId,
        unidadId: unidadId,
        onAtender: onAtender,
      ),
    );
  }

  @override
  State<SosOverlay> createState() => _SosOverlayState();
}

class _SosOverlayState extends State<SosOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _tintOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..repeat(reverse: true);

    _iconScale = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _tintOpacity = Tween<double>(begin: 0.06, end: 0.20).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    SosAudioService.stop();
    super.dispose();
  }

  void _dismiss(BuildContext ctx) {
    SosAudioService.stop();
    Navigator.of(ctx).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fondo oscuro base
              const ColoredBox(color: Color(0xEE080C14)),
              // Pulso rojo sobre el fondo
              ColoredBox(
                color: GloboColors.sosPrimary
                    .withOpacity(_tintOpacity.value),
              ),
              // Contenido central
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GloboSpacing.xl,
                    vertical: GloboSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ícono pulsante
                      Transform.scale(
                        scale: _iconScale.value,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GloboColors.sosPrimary,
                            boxShadow: [
                              BoxShadow(
                                color: GloboColors.sosPrimary.withOpacity(
                                    0.4 + _tintOpacity.value),
                                blurRadius: 32,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.emergency_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                      ),
                      const SizedBox(height: GloboSpacing.lg),

                      // Etiqueta de protocolo
                      Text(
                        'PROTOCOLO SOS',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: GloboColors.sosPulse,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: GloboSpacing.sm),

                      // Título de la notificación
                      Text(
                        widget.titulo,
                        style: GloboTypography.headlineMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Cuerpo opcional
                      if (widget.cuerpo.isNotEmpty) ...[
                        const SizedBox(height: GloboSpacing.xs),
                        Text(
                          widget.cuerpo,
                          style: GloboTypography.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: GloboSpacing.lg),

                      // Tarjeta de información
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: GloboSpacing.md,
                          vertical: GloboSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: GloboRadius.cardRadius,
                          border: Border.all(
                            color: GloboColors.sosPrimary.withOpacity(0.45),
                          ),
                        ),
                        child: Column(
                          children: [
                            _InfoTile(
                              icon: Icons.person_outline_rounded,
                              label: 'Operador',
                              value: widget.operadorId,
                            ),
                            const Divider(
                              color: Colors.white12,
                              height: 14,
                              thickness: 0.5,
                            ),
                            _InfoTile(
                              icon: Icons.local_shipping_outlined,
                              label: 'Unidad',
                              value: widget.unidadId,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: GloboSpacing.xl),

                      // Botón principal: Atender
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _dismiss(context);
                            widget.onAtender?.call();
                          },
                          icon: const Icon(
                              Icons.emergency_share_outlined, size: 18),
                          label: const Text('ATENDER EMERGENCIA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GloboColors.sosPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: GloboSpacing.md,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(height: GloboSpacing.sm),

                      // Botón secundario: Ignorar
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => _dismiss(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white38,
                            padding: const EdgeInsets.symmetric(
                              vertical: GloboSpacing.sm,
                            ),
                          ),
                          child: const Text(
                            'Ignorar',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: GloboSpacing.sm),
        Text(
          '$label: ',
          style: GloboTypography.caption.copyWith(color: Colors.white38),
        ),
        Expanded(
          child: Text(
            value,
            style: GloboTypography.labelLarge.copyWith(
              color: Colors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
