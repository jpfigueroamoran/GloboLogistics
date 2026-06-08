import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
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

            // Botón principal SOS
            ScaleTransition(
              scale: sosState.isActive ? _pulseAnimation : kAlwaysCompleteAnimation,
              child: _SosMainButton(
                isActive: sosState.isActive,
                isLoading:
                    sosState.status == SosStatus.activating,
                onPressed: () => _handleSosPress(sosState),
              ),
            ),

            const SizedBox(height: GloboSpacing.xl),

            // Status info
            _SosStatusInfo(status: sosState.status),

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

  void _handleSosPress(SosState sosState) {
    if (sosState.isActive) {
      ref.read(sosProvider.notifier).cancelarSOS();
      Navigator.pop(context);
      return;
    }
    ref.read(sosProvider.notifier).activarSOS(
          viajeId: widget.viajeId,
          operadorId: widget.operadorId,
          unidadId: widget.unidadId,
        );
  }
}

class _SosMainButton extends StatelessWidget {
  final bool isActive;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SosMainButton({
    required this.isActive,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
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
