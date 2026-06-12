import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../core/services/ocr_normalization_service.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

class CargaCombustiblePage extends ConsumerStatefulWidget {
  final String viajeId;
  final String operadorId;
  final String unidadId;

  static const routeName = '/operador/combustible';

  const CargaCombustiblePage({
    super.key,
    required this.viajeId,
    required this.operadorId,
    required this.unidadId,
  });

  @override
  ConsumerState<CargaCombustiblePage> createState() =>
      _CargaCombustiblePageState();
}

class _CargaCombustiblePageState extends ConsumerState<CargaCombustiblePage> {
  final _formKey        = GlobalKey<FormState>();
  final _litrosCtrl     = TextEditingController();
  final _precioCtrl     = TextEditingController();
  final _totalCtrl      = TextEditingController();
  final _folioCtrl      = TextEditingController();
  final _estacionCtrl   = TextEditingController();

  File? _imagenFile;
  bool _procesandoOcr  = false;
  bool _guardando      = false;
  double _ocrConfianza = 0;
  String? _ocrTexto;

  @override
  void dispose() {
    _litrosCtrl.dispose();
    _precioCtrl.dispose();
    _totalCtrl.dispose();
    _folioCtrl.dispose();
    _estacionCtrl.dispose();
    super.dispose();
  }

  // ── Captura de imagen + OCR ──────────────────────────────────────────────

  Future<void> _capturar(ImageSource source) async {
    final picker = ImagePicker();
    // Compresión agresiva: la foto se guarda en Firestore (límite 1 MiB/doc)
    final file = await picker.pickImage(
      source: source,
      imageQuality: 55,
      maxWidth: 1280,
    );
    if (file == null) return;

    setState(() {
      _imagenFile = File(file.path);
      _procesandoOcr = true;
      _ocrConfianza = 0;
      _ocrTexto = null;
    });

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(inputImage);
      recognizer.close();

      final texto = OcrNormalizationService.normalize(recognized.text);
      _ocrTexto = texto;

      final litros = OcrNormalizationService.extractLitros(texto);
      final precio = OcrNormalizationService.extractPrecioPorLitro(texto);
      final monto  = OcrNormalizationService.extractMonto(texto);
      final folio  = OcrNormalizationService.extractFolio(texto);

      final campos = [litros, precio, monto, folio].where((e) => e != null).length;
      bool coherente = false;
      if (litros != null && precio != null && monto != null) {
        coherente = OcrNormalizationService.validarCoherenciaMatematica(
          monto: monto,
          litros: litros,
          precioPorLitro: precio,
        );
      }
      _ocrConfianza = (campos / 4.0) * (coherente ? 1.0 : 0.85);

      // Pre-llenar campos solo si no están ya editados
      if (litros != null && _litrosCtrl.text.isEmpty) {
        _litrosCtrl.text = litros.toStringAsFixed(2);
      }
      if (precio != null && _precioCtrl.text.isEmpty) {
        _precioCtrl.text = precio.toStringAsFixed(2);
      }
      if (monto != null && _totalCtrl.text.isEmpty) {
        _totalCtrl.text = monto.toStringAsFixed(2);
      }
      if (folio != null && _folioCtrl.text.isEmpty) {
        _folioCtrl.text = folio;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en OCR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoOcr = false);
    }
  }

  // ── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagenFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjunta la foto del ticket')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      // 1. Codificar foto del ticket en base64 (plan gratuito, sin Storage)
      final fotoBytes = await _imagenFile!.readAsBytes();
      if (fotoBytes.length > 700 * 1024) {
        throw Exception(
            'La foto excede 700 KB; vuelve a capturarla con menos detalle.');
      }
      final fotoB64 = base64Encode(fotoBytes);

      // 2. Obtener posición actual para registrar dónde se cargó combustible
      Map<String, dynamic>? posicionActual;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 5));
        posicionActual = {'lat': pos.latitude, 'lng': pos.longitude};
      } catch (_) {
        // Posición opcional — no bloquear si falla
      }

      // 3. Guardar costos_operativos
      final litros = double.tryParse(_litrosCtrl.text) ?? 0;
      final precio = double.tryParse(_precioCtrl.text) ?? 0;
      final total  = double.tryParse(_totalCtrl.text) ?? 0;

      final costoData = <String, dynamic>{
        'viaje_id':    widget.viajeId,
        'unidad_id':   widget.unidadId,
        'operador_id': widget.operadorId,
        'tipo':        'combustible',
        'monto':       total,
        'litros':      litros,
        'precio_litro': precio,
        'proveedor':   _estacionCtrl.text.trim(),
        'folio':       _folioCtrl.text.trim(),
        'ticket_foto_b64': fotoB64,
        'verificado':  false,
        'sincronizado': true,
        'created_at':  FieldValue.serverTimestamp(),
        'datos_ocr': {
          'texto_completo': _ocrTexto,
          'litros_detectados': litros,
          'monto_detectado': total,
          'confianza': _ocrConfianza,
        },
        if (posicionActual != null) 'posicion_carga': posicionActual,
      };

      final db = sl<FirestoreDatasource>();
      await db.crearCostoOperativo(costoData);

      // 4. Actualizar TCO del viaje (tipo combustible)
      await db.actualizarTcoViaje(widget.viajeId, total, 'combustible');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket registrado correctamente'),
          backgroundColor: GloboColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carga de Combustible')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Foto del ticket ─────────────────────────────────────────
            _TicketFotoSection(
              imagenFile: _imagenFile,
              procesandoOcr: _procesandoOcr,
              ocrConfianza: _ocrConfianza,
              onCapturar: _capturar,
            ),
            const SizedBox(height: 16),

            // ── Datos del ticket ────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_gas_station_outlined,
                            size: 18, color: GloboColors.primary),
                        const SizedBox(width: 8),
                        Text('Datos del Ticket',
                            style: GloboTypography.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _litrosCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Litros *',
                              suffixText: 'L',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]')),
                            ],
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _precioCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Precio/L',
                              prefixText: '\$',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _totalCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Total *',
                              prefixText: '\$',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]')),
                            ],
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _folioCtrl,
                            decoration: const InputDecoration(
                              labelText: 'No. Folio',
                            ),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _estacionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Estación / Proveedor',
                        hintText: 'Nombre de la gasolinera',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: const Text('Registrar Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sección de foto ───────────────────────────────────────────────────────────

class _TicketFotoSection extends StatelessWidget {
  final File? imagenFile;
  final bool procesandoOcr;
  final double ocrConfianza;
  final Future<void> Function(ImageSource) onCapturar;

  const _TicketFotoSection({
    required this.imagenFile,
    required this.procesandoOcr,
    required this.ocrConfianza,
    required this.onCapturar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: GloboColors.primary),
                const SizedBox(width: 8),
                Text('Foto del Ticket', style: GloboTypography.titleMedium),
                const Spacer(),
                if (ocrConfianza > 0)
                  Chip(
                    label: Text(
                      'OCR ${(ocrConfianza * 100).toStringAsFixed(0)}%',
                      style: GloboTypography.labelSmall,
                    ),
                    backgroundColor:
                        ocrConfianza >= 0.75
                            ? GloboColors.successLight
                            : GloboColors.warningLight,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (imagenFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  imagenFile!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            if (procesandoOcr) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text('Extrayendo datos del ticket...',
                  style: GloboTypography.caption),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Cámara'),
                    onPressed: procesandoOcr
                        ? null
                        : () => onCapturar(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Galería'),
                    onPressed: procesandoOcr
                        ? null
                        : () => onCapturar(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
