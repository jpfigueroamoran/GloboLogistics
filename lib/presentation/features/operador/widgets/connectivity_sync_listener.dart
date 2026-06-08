import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../domain/repositories/i_actividad_repository.dart';
import '../../../../injection_container.dart';

class ConnectivitySyncListener extends StatefulWidget {
  final Widget child;

  const ConnectivitySyncListener({super.key, required this.child});

  @override
  State<ConnectivitySyncListener> createState() => _ConnectivitySyncListenerState();
}

class _ConnectivitySyncListenerState extends State<ConnectivitySyncListener> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        // Ejecutar vaciado de cola (sincronizarPendientes) en background
        _sincronizar();
      }
    });
  }

  Future<void> _sincronizar() async {
    try {
      final repo = sl<IActividadRepository>();
      await repo.sincronizarPendientes();
    } catch (_) {
      // Si falla, volverá a intentar en la próxima reconexión o manualmente
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
