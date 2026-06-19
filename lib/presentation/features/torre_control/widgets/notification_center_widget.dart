import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import 'alerta_panel_widget.dart' show alertasStreamProvider;

class NotificationCenterWidget extends ConsumerStatefulWidget {
  const NotificationCenterWidget({super.key});

  @override
  ConsumerState<NotificationCenterWidget> createState() => _NotificationCenterWidgetState();
}

class _NotificationCenterWidgetState extends ConsumerState<NotificationCenterWidget> {
  final GlobalKey _iconKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _closeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    final RenderBox renderBox = _iconKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Capa invisible para cerrar al hacer tap fuera
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 10,
            right: 20,
            width: 380,
            child: Material(
              color: Colors.transparent,
              child: _NotificationPanel(onClose: _closeOverlay),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  void dispose() {
    _closeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alertas = ref.watch(alertasStreamProvider).valueOrNull ?? [];
    final unreadCount = alertas.length; // Para demo, todas son no leídas

    // Listen to changes to show a SnackBar when a new alert comes in
    ref.listen(alertasStreamProvider, (prev, next) {
      final prevList = prev?.valueOrNull ?? [];
      final nextList = next.valueOrNull ?? [];
      if (nextList.length > prevList.length) {
        // Nueva alerta
        final nueva = nextList.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GloboColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: GloboRadius.buttonRadius),
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: GloboSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¡Nueva Alerta Detectada!', style: GloboTypography.titleMedium.copyWith(color: Colors.white)),
                      Text('Operador: ${nueva['operador_id']}', style: GloboTypography.bodyMedium.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'VER',
              textColor: Colors.white,
              onPressed: () {
                _showOverlay();
              },
            ),
          ),
        );
      }
    });

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: _iconKey,
          icon: const Icon(Icons.notifications_none_outlined, size: 24, color: GloboColors.steelGray),
          onPressed: _toggleOverlay,
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: GloboColors.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationPanel extends ConsumerWidget {
  final VoidCallback onClose;

  const _NotificationPanel({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasStreamProvider).valueOrNull ?? [];

    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        color: GloboColors.surface,
        borderRadius: GloboRadius.cardRadius,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 8)),
        ],
        border: Border.all(color: GloboColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications, color: GloboColors.primary),
                    const SizedBox(width: GloboSpacing.sm),
                    Text('Centro de Notificaciones', style: GloboTypography.titleMedium),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (alertas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(GloboSpacing.xl),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: GloboColors.success.withAlpha(100)),
                  const SizedBox(height: GloboSpacing.md),
                  Text('Todo en orden', style: GloboTypography.titleMedium.copyWith(color: GloboColors.textSecondary)),
                  const Text('No tienes notificaciones pendientes.'),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: alertas.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final alerta = alertas[index];
                  final esSos = alerta['tipo'] == 'sos';
                  final color = esSos ? GloboColors.error : GloboColors.warning;
                  
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Acción al tocar
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(GloboSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(esSos ? Icons.sos : Icons.water_drop, color: color, size: 20),
                            ),
                            const SizedBox(width: GloboSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    esSos ? 'S.O.S. Activado' : 'Varianza de Combustible',
                                    style: GloboTypography.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Operador: ${alerta['operador_id']}',
                                    style: GloboTypography.bodyMedium,
                                  ),
                                  Text(
                                    'Viaje: ${alerta['viaje_id']} | Unidad: ${alerta['unidad_id']}',
                                    style: GloboTypography.caption,
                                  ),
                                  const SizedBox(height: GloboSpacing.sm),
                                  Text(
                                    'Hace unos momentos',
                                    style: GloboTypography.labelSmall.copyWith(color: GloboColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.sm),
            child: TextButton.icon(
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Cerrar panel'),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}
