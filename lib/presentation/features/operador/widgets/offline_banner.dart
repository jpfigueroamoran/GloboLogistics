import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/theme_constants.dart';

/// Banner persistente que aparece cuando el dispositivo pierde conexión.
/// Tranquiliza al operador: sus registros se guardan localmente (Firestore
/// con persistencia offline) y se sincronizan solos al volver la señal.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_actualizar);
    _sub = Connectivity().onConnectivityChanged.listen(_actualizar);
  }

  void _actualizar(List<ConnectivityResult> results) {
    final sinRed = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (mounted && sinRed != _offline) {
      setState(() => _offline = sinRed);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: !_offline
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: GloboColors.warning,
              padding: const EdgeInsets.symmetric(
                  horizontal: GloboSpacing.md, vertical: 8),
              child: Row(children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 16, color: Colors.white),
                const SizedBox(width: GloboSpacing.sm),
                Expanded(
                  child: Text(
                    'Sin conexión — tus registros se guardan en el teléfono '
                    'y se sincronizarán automáticamente',
                    style: GloboTypography.caption
                        .copyWith(color: Colors.white),
                  ),
                ),
              ]),
            ),
    );
  }
}
