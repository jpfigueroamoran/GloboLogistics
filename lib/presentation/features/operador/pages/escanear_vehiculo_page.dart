import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

/// Prefijo del QR pegado en la cabina: GLUNIDAD:{unidadId}:{placas}
const _qrPrefix = 'GLUNIDAD';

/// Resultado de la asociación devuelto al cerrar la pantalla.
class VehiculoAsociado {
  final String unidadId;
  final String placas;
  const VehiculoAsociado(this.unidadId, this.placas);
}

/// Escáner de QR para que el operador asocie su dispositivo al vehículo que
/// conduce hoy. Pensado para uso de una mano y sin posibilidad de error:
/// el código está físicamente en el vehículo correcto.
class EscanearVehiculoPage extends StatefulWidget {
  final String operadorUid;
  final String? unidadPrevia;

  const EscanearVehiculoPage({
    super.key,
    required this.operadorUid,
    this.unidadPrevia,
  });

  @override
  State<EscanearVehiculoPage> createState() => _EscanearVehiculoPageState();
}

class _EscanearVehiculoPageState extends State<EscanearVehiculoPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _procesando = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.startsWith('$_qrPrefix:'),
            orElse: () => null);

    if (raw == null) {
      // Hay un QR pero no es de un vehículo Globo
      setState(() => _error = 'Ese código no corresponde a un vehículo');
      return;
    }

    final partes = raw.split(':');
    if (partes.length < 2 || partes[1].isEmpty) {
      setState(() => _error = 'Código de vehículo inválido');
      return;
    }
    final unidadId = partes[1];
    final placas = partes.length >= 3 ? partes.sublist(2).join(':') : unidadId;

    setState(() {
      _procesando = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();

    try {
      await sl<FirestoreDatasource>().asociarVehiculoOperador(
        operadorUid: widget.operadorUid,
        unidadId: unidadId,
        unidadPrevia: widget.unidadPrevia,
      );
      if (!mounted) return;
      Navigator.of(context).pop(VehiculoAsociado(unidadId, placas));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _error =
            'No se pudo asociar el vehículo. Verifica tu conexión e intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear vehículo'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Marco guía
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          // Instrucción / estado
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_procesando)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: GloboRadius.cardRadius,
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text('Asociando vehículo…',
                          style: TextStyle(color: Colors.white)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: GloboRadius.cardRadius,
                    ),
                    child: Text(
                      _error ??
                          'Apunta al código QR pegado en la cabina del vehículo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            _error != null ? GloboColors.warningAccent : Colors.white,
                      ),
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
