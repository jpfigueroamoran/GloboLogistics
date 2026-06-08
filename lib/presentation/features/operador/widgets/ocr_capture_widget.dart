import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../core/services/ocr_normalization_service.dart';
import '../../../../domain/entities/costo_operativo.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

class OcrResult {
  final String textoCompleto;
  final double? montoDetectado;
  final double? litrosDetectados;
  final String? folioDetectado;
  final double confianza;

  const OcrResult({
    required this.textoCompleto,
    this.montoDetectado,
    this.litrosDetectados,
    this.folioDetectado,
    this.confianza = 0,
  });
}

final _ocrStateProvider = StateProvider<_OcrState>((_) => const _OcrState());

class _OcrState {
  final bool isProcessing;
  final OcrResult? result;
  final String? imagePath;
  final String? error;

  const _OcrState({
    this.isProcessing = false,
    this.result,
    this.imagePath,
    this.error,
  });

  _OcrState copyWith({
    bool? isProcessing,
    OcrResult? result,
    String? imagePath,
    String? error,
  }) =>
      _OcrState(
        isProcessing: isProcessing ?? this.isProcessing,
        result: result ?? this.result,
        imagePath: imagePath ?? this.imagePath,
        error: error ?? this.error,
      );
}

class OcrCaptureWidget extends ConsumerWidget {
  final String viajeId;
  final String operadorId;
  final String unidadId;

  const OcrCaptureWidget({
    super.key,
    required this.viajeId,
    required this.operadorId,
    required this.unidadId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_ocrStateProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.document_scanner_outlined,
                    size: 20, color: GloboColors.primary),
                const SizedBox(width: GloboSpacing.sm),
                Text('Captura de Documentos',
                    style: GloboTypography.titleMedium),
              ],
            ),
            const SizedBox(height: GloboSpacing.sm),
            Text(
              'Captura tickets de diésel y facturas. El OCR extraerá los datos automáticamente.',
              style: GloboTypography.bodyMedium,
            ),
            const SizedBox(height: GloboSpacing.md),

            if (state.imagePath != null) ...[
              ClipRRect(
                borderRadius: GloboRadius.buttonRadius,
                child: Image.file(
                  File(state.imagePath!),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: GloboSpacing.sm),
            ],

            if (state.isProcessing)
              const LinearProgressIndicator(
                  color: GloboColors.primaryAccent),

            if (state.result != null)
              _OcrResultCard(result: state.result!),

            const SizedBox(height: GloboSpacing.md),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Cámara'),
                    onPressed: state.isProcessing
                        ? null
                        : () => _capture(context, ref,
                            ImageSource.camera),
                  ),
                ),
                const SizedBox(width: GloboSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería'),
                    onPressed: state.isProcessing
                        ? null
                        : () => _capture(context, ref,
                            ImageSource.gallery),
                  ),
                ),
              ],
            ),

            if (state.result != null && viajeId.isNotEmpty) ...[
              const SizedBox(height: GloboSpacing.sm),
              _TipoDocumentoSelector(
                onSave: (tipo) =>
                    _guardarCosto(context, ref, tipo, state),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _capture(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: source, imageQuality: 90);
    if (file == null) return;

    ref.read(_ocrStateProvider.notifier).update((s) =>
        s.copyWith(isProcessing: true, imagePath: file.path));

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(inputImage);
      recognizer.close();

      final result = _parseOcrText(recognized.text);
      ref.read(_ocrStateProvider.notifier).update(
          (s) => s.copyWith(isProcessing: false, result: result));
    } catch (e) {
      ref.read(_ocrStateProvider.notifier).update((s) =>
          s.copyWith(isProcessing: false, error: e.toString()));
    }
  }

  OcrResult _parseOcrText(String rawText) {
    // Normalización portada del engine anti-fraude de LitroExacto v2.0
    final text = OcrNormalizationService.normalize(rawText);

    final monto = OcrNormalizationService.extractMonto(text);
    final litros = OcrNormalizationService.extractLitros(text);
    final precio = OcrNormalizationService.extractPrecioPorLitro(text);
    final folio = OcrNormalizationService.extractFolio(text);

    // Coherencia matemática: precio × litros ≈ total
    bool coherente = false;
    if (monto != null && litros != null && precio != null) {
      coherente = OcrNormalizationService.validarCoherenciaMatematica(
        monto: monto,
        litros: litros,
        precioPorLitro: precio,
      );
    }

    // Confianza basada en campos detectados + coherencia matemática
    final camposDetectados = [monto, litros, precio, folio]
        .where((e) => e != null)
        .length;
    final confianza =
        (camposDetectados / 4.0) * (coherente ? 1.0 : 0.85);

    return OcrResult(
      textoCompleto: text,
      montoDetectado: monto,
      litrosDetectados: litros,
      folioDetectado: folio,
      confianza: confianza,
    );
  }

  Future<void> _guardarCosto(BuildContext context, WidgetRef ref,
      TipoCosto tipo, _OcrState state) async {
    final result = state.result;
    if (result == null || result.montoDetectado == null) return;
    
    try {
      final remote = sl<FirestoreDatasource>();
      
      // Actualizar TCO del viaje
      final String tipoStr = tipo == TipoCosto.diesel ? 'combustible' 
          : tipo == TipoCosto.peaje ? 'peajes' 
          : tipo == TipoCosto.mantenimiento ? 'mantenimiento' : 'otros';
          
      await remote.actualizarTcoViaje(viajeId, result.montoDetectado!, tipoStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Costo guardado: \$${result.montoDetectado} en $tipoStr'),
            backgroundColor: GloboColors.success,
          ),
        );
      }
      ref.read(_ocrStateProvider.notifier).update((_) => const _OcrState());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: GloboColors.error),
        );
      }
    }
  }
}

class _OcrResultCard extends StatelessWidget {
  final OcrResult result;

  const _OcrResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GloboSpacing.sm),
      decoration: BoxDecoration(
        color: GloboColors.infoLight,
        borderRadius: GloboRadius.buttonRadius,
        border: const Border(
            left: BorderSide(color: GloboColors.primaryAccent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datos detectados',
              style: GloboTypography.labelLarge
                  .copyWith(color: GloboColors.info)),
          const SizedBox(height: GloboSpacing.xs),
          if (result.montoDetectado != null)
            _DataRow(
                label: 'Monto',
                value: '\$${result.montoDetectado!.toStringAsFixed(2)}'),
          if (result.litrosDetectados != null)
            _DataRow(
                label: 'Litros',
                value: '${result.litrosDetectados!.toStringAsFixed(2)} L'),
          if (result.folioDetectado != null)
            _DataRow(
                label: 'Folio', value: result.folioDetectado!),
          _DataRow(
              label: 'Confianza',
              value:
                  '${(result.confianza * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: GloboTypography.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: GloboTypography.monoData.copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipoDocumentoSelector extends StatelessWidget {
  final ValueChanged<TipoCosto> onSave;

  const _TipoDocumentoSelector({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de documento:',
            style: GloboTypography.labelLarge),
        const SizedBox(height: GloboSpacing.sm),
        Wrap(
          spacing: GloboSpacing.sm,
          runSpacing: GloboSpacing.sm,
          children: [
            _TipoChip(
                tipo: TipoCosto.diesel,
                icon: Icons.local_gas_station,
                onTap: onSave),
            _TipoChip(
                tipo: TipoCosto.mantenimiento,
                icon: Icons.build_outlined,
                onTap: onSave),
            _TipoChip(
                tipo: TipoCosto.grua,
                icon: Icons.fire_truck_outlined,
                onTap: onSave),
            _TipoChip(
                tipo: TipoCosto.peaje,
                icon: Icons.toll_outlined,
                onTap: onSave),
          ],
        ),
      ],
    );
  }
}

class _TipoChip extends StatelessWidget {
  final TipoCosto tipo;
  final IconData icon;
  final ValueChanged<TipoCosto> onTap;

  const _TipoChip(
      {required this.tipo, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(tipo.name.toUpperCase()),
      onPressed: () => onTap(tipo),
      labelStyle: GloboTypography.labelSmall,
    );
  }
}
